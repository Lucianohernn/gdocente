import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';

import '../dao/asistencia_dao.dart';
import '../dao/evaluacion_dao.dart';
import '../dao/nota_dao.dart';
import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../models/evaluacion_model.dart';
import '../models/materia_model.dart';
import '../models/nota_model.dart';
import '../utils/formato.dart';
import '../utils/telefono.dart';
import 'alumno_service.dart';
import 'lector_excel.dart';
import 'resumen_academico.dart';
import 'servicio_exception.dart';

/// Exportación de una materia a .xlsx (respaldo y planilla para imprimir) e
/// importación desde .xlsx (alumnos, asistencias y notas).
///
/// El archivo exportado se puede volver a importar (respaldo completo), y su
/// hoja "Alumnos" sirve de plantilla para cargar una lista de alumnos.
class ExcelService {
  // Los nombres de hojas y encabezados vienen de LectorExcel: así la
  // exportación y la importación usan siempre el mismo formato.

  final _alumnoService = AlumnoService();
  final _asistenciaDao = AsistenciaDao();
  final _evaluacionDao = EvaluacionDao();
  final _notaDao = NotaDao();

  /// Genera el .xlsx de la materia y devuelve el archivo creado.
  Future<File> exportarMateria(MateriaModel materia) async {
    final alumnos = await _alumnoService.listarActivos(materia.id!);
    final asistencias = await _asistenciaDao.listarPorMateria(materia.id!);
    final evaluaciones = await _evaluacionDao.listarPorMateria(materia.id!);
    final notas = await _notaDao.listarPorMateria(materia.id!);

    final excel = Excel.createExcel();
    final hojaInicial = excel.getDefaultSheet()!;

    // 1) Resumen
    excel.rename(hojaInicial, 'Resumen');
    final resumen = excel['Resumen'];
    _encabezado(resumen, [
      'Alumno', 'Teléfono', 'Asistencia %', 'Clases asistidas',
      'Clases que cuentan', 'Justificadas', 'Promedio', 'A recuperar',
    ]);
    for (final a in alumnos) {
      final r = ResumenAcademico.calcular(
        asistencias: asistencias.where((s) => s.alumnoId == a.id),
        evaluaciones: evaluaciones,
        notas: notas.where((n) => n.alumnoId == a.id),
      );
      final pct = r.porcentajeAsistencia;
      final prom = r.promedio;
      resumen.appendRow([
        TextCellValue(a.nombreCompleto),
        TextCellValue(Telefono.formatear(a.telefono)),
        pct == null ? null : IntCellValue(pct.round()),
        IntCellValue(r.clasesAsistidas),
        IntCellValue(r.clasesComputables),
        IntCellValue(r.justificadas),
        prom == null ? null : DoubleCellValue(_redondear(prom)),
        TextCellValue(r.aRecuperar.map((n) => n.evaluacion).join(', ')),
      ]);
    }
    resumen.appendRow([]);
    for (final nota in const [
      'Clases asistidas = presentes + llegadas tarde.',
      'Clases que cuentan = presentes + llegadas tarde + ausentes '
          '(las faltas justificadas no cuentan ni a favor ni en contra).',
      'Asistencia % = clases asistidas / clases que cuentan × 100.',
      'Promedio: el recuperatorio reemplaza a la nota original. '
          'A recuperar: evaluaciones con nota final menor a 6.',
    ]) {
      resumen.appendRow([TextCellValue(nota)]);
    }
    _anchos(resumen, [32, 20, 13, 15, 18, 13, 10, 30]);

    // 2) Asistencia: una columna por clase
    final hojaAsist = excel[LectorExcel.hojaAsistencia];
    final fechas = asistencias.map((s) => s.fecha).toSet().toList()..sort();
    _encabezado(hojaAsist, ['Alumno', ...fechas.map(Formato.fecha)]);
    final estado = {
      for (final s in asistencias) '${s.alumnoId}|${s.fecha}': s.estado.codigo
    };
    for (final a in alumnos) {
      hojaAsist.appendRow([
        TextCellValue(a.nombreCompleto),
        for (final f in fechas)
          TextCellValue(estado['${a.id}|$f'] ?? ''),
      ]);
    }
    hojaAsist.appendRow([]);
    hojaAsist.appendRow([
      TextCellValue('P = Presente · A = Ausente · T = Tarde · J = Justificada'),
    ]);
    _anchos(hojaAsist, [32, for (final _ in fechas) 11]);

    // 3) Notas: nota y recuperatorio de cada evaluación
    final hojaNotas = excel[LectorExcel.hojaNotas];
    _encabezado(hojaNotas, [
      'Alumno',
      for (final e in evaluaciones) ...['${e.nombre} (${Formato.fecha(e.fecha)})', LectorExcel.tituloRecuperatorio],
    ]);
    final nota = {for (final n in notas) '${n.alumnoId}|${n.evaluacionId}': n};
    for (final a in alumnos) {
      hojaNotas.appendRow([
        TextCellValue(a.nombreCompleto),
        for (final e in evaluaciones) ...[
          _celdaNota(nota['${a.id}|${e.id}']?.nota),
          _celdaNota(nota['${a.id}|${e.id}']?.recuperatorio),
        ],
      ]);
    }
    _anchos(hojaNotas, [32, for (final _ in evaluaciones) ...[22, 9]]);

    // 4) Alumnos (mismo formato que la importación)
    final hojaAl = excel[LectorExcel.hojaAlumnos];
    _encabezado(hojaAl, ['Nombre completo', 'Teléfono']);
    for (final a in alumnos) {
      hojaAl.appendRow([
        TextCellValue(a.nombreCompleto),
        TextCellValue(Telefono.paraEditar(a.telefono)),
      ]);
    }
    _anchos(hojaAl, [32, 16]);

    excel.setDefaultSheet('Resumen');
    final bytes = excel.encode();
    if (bytes == null) throw const ServicioException('No se pudo generar el Excel');

    final dir = await getTemporaryDirectory();
    final nombre = _nombreArchivo(materia);
    final archivo = File('${dir.path}${Platform.pathSeparator}$nombre');
    return archivo.writeAsBytes(bytes, flush: true);
  }

  /// Importa a la materia lo que encuentre en el Excel:
  /// - Alumnos: los que no existen se agregan (mismas validaciones que el alta
  ///   manual); los que ya están (mismo nombre) se dejan como están.
  /// - Asistencias: se cargan por alumno y fecha; si ya había una para ese
  ///   día, la del Excel la reemplaza.
  /// - Evaluaciones y notas: las evaluaciones se buscan por nombre (si no
  ///   existen se crean) y sus notas reemplazan a las anteriores.
  /// Las asistencias y notas se asocian a los alumnos por nombre completo.
  Future<ResultadoImportacion> importarMateria(
      List<int> bytes, int materiaId) async {
    final datos = LectorExcel.leer(bytes);
    final avisos = [...datos.advertencias];

    // 1) Alumnos
    final existentes = await _alumnoService.listarActivos(materiaId);
    final claves = {for (final a in existentes) LectorExcel.clave(a.nombreCompleto)};
    var agregados = 0, yaExistian = 0;
    for (final f in datos.alumnos) {
      if (claves.contains(LectorExcel.clave(f.nombre))) {
        yaExistian++;
        continue;
      }
      try {
        await _alumnoService.guardar(AlumnoModel(
          materiaId: materiaId,
          nombreCompleto: f.nombre,
          telefono: f.telefono,
          fechaAlta: DateTime.now().toIso8601String(),
        ));
        claves.add(LectorExcel.clave(f.nombre));
        agregados++;
      } on ServicioException catch (e) {
        avisos.add('Alumnos, fila ${f.fila}'
            '${f.nombre.isEmpty ? '' : ' (${f.nombre})'}: ${e.mensaje}');
      }
    }

    // Alumnos de la materia ya actualizados: nombre → id
    final idPorNombre = {
      for (final a in await _alumnoService.listarActivos(materiaId))
        LectorExcel.clave(a.nombreCompleto): a.id!
    };
    final noEncontrados = <String>{};
    int? idDe(String nombre) {
      final id = idPorNombre[LectorExcel.clave(nombre)];
      if (id == null) noEncontrados.add(nombre);
      return id;
    }

    // 2) Asistencias, agrupadas por día (una transacción por día)
    final porDia = <String, Map<int, EstadoAsistencia?>>{};
    for (final s in datos.asistencias) {
      final id = idDe(s.nombre);
      if (id != null) (porDia[s.fecha] ??= {})[id] = s.estado;
    }
    var asistencias = 0;
    for (final dia in porDia.entries) {
      await _asistenciaDao.guardarDia(dia.key, dia.value);
      asistencias += dia.value.length;
    }

    // 3) Evaluaciones y notas
    var evaluacionesCreadas = 0, notasCargadas = 0;
    for (final e in datos.evaluaciones) {
      var evaluacionId = await _evaluacionDao.buscarId(materiaId, e.nombre);
      if (evaluacionId == null) {
        evaluacionId = await _evaluacionDao.insertar(EvaluacionModel(
            materiaId: materiaId, nombre: e.nombre, fecha: e.fecha));
        evaluacionesCreadas++;
      }
      final planilla = <NotaModel>[];
      for (final n in e.notas) {
        final id = idDe(n.alumno);
        if (id == null) continue;
        planilla.add(NotaModel(
          evaluacionId: evaluacionId,
          alumnoId: id,
          nota: n.nota,
          recuperatorio: n.recuperatorio,
        ));
      }
      await _notaDao.guardarPlanilla(planilla);
      notasCargadas += planilla.length;
    }

    for (final nombre in noEncontrados) {
      avisos.add('"$nombre" aparece en Asistencia o Notas pero no está entre '
          'los alumnos de la materia: sus datos no se importaron');
    }

    return ResultadoImportacion(
      alumnosAgregados: agregados,
      alumnosExistentes: yaExistian,
      asistencias: asistencias,
      evaluacionesCreadas: evaluacionesCreadas,
      notas: notasCargadas,
      avisos: avisos,
    );
  }

  // ---------- auxiliares ----------

  static void _encabezado(Sheet hoja, List<String> titulos) {
    hoja.appendRow(titulos.map(TextCellValue.new).toList());
    final estilo = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#DCE3F5'),
    );
    for (var c = 0; c < titulos.length; c++) {
      hoja
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = estilo;
    }
  }

  static void _anchos(Sheet hoja, List<double> anchos) {
    for (var c = 0; c < anchos.length; c++) {
      hoja.setColumnWidth(c, anchos[c]);
    }
  }

  static CellValue? _celdaNota(double? n) =>
      n == null ? null : DoubleCellValue(n);

  static double _redondear(double n) => (n * 100).round() / 100;

  static String _nombreArchivo(MateriaModel m) {
    final base = m.nombre
        .replaceAll(RegExp(r'[^\w\sáéíóúÁÉÍÓÚñÑ-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return 'GDocente_${base}_${m.anio}anio_${Formato.fechaIso(DateTime.now())}.xlsx';
  }
}

class ResultadoImportacion {
  final int alumnosAgregados;
  final int alumnosExistentes;
  final int asistencias;
  final int evaluacionesCreadas;
  final int notas;
  final List<String> avisos;

  const ResultadoImportacion({
    required this.alumnosAgregados,
    required this.alumnosExistentes,
    required this.asistencias,
    required this.evaluacionesCreadas,
    required this.notas,
    required this.avisos,
  });

  /// Texto para mostrar al docente al terminar.
  String get detalle => [
        '$alumnosAgregados alumno(s) agregado(s)'
            '${alumnosExistentes > 0 ? ' ($alumnosExistentes ya estaban)' : ''}.',
        if (asistencias > 0) '$asistencias registro(s) de asistencia.',
        if (evaluacionesCreadas > 0) '$evaluacionesCreadas evaluación(es) nueva(s).',
        if (notas > 0) '$notas nota(s).',
        if (avisos.isNotEmpty) ...[
          '',
          'Avisos (${avisos.length}):',
          ...avisos.map((a) => '• $a'),
        ],
      ].join('\n');
}
