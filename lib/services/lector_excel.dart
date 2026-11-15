import 'package:excel/excel.dart';

import '../models/asistencia_model.dart';
import '../utils/formato.dart';
import 'servicio_exception.dart';

/// Lee un .xlsx y devuelve los datos encontrados, SIN tocar la base de datos.
/// Es lógica pura: por eso se puede probar armando un Excel en memoria.
///
/// Acepta dos formatos:
/// - El Excel exportado por GDocente: hojas "Alumnos", "Asistencia" y "Notas".
/// - Una lista simple: columna A nombre completo, columna B teléfono (en la
///   hoja "Alumnos" o, si no existe, en la primera hoja).
class LectorExcel {
  LectorExcel._();

  static const hojaAlumnos = 'Alumnos';
  static const hojaAsistencia = 'Asistencia';
  static const hojaNotas = 'Notas';
  static const tituloRecuperatorio = 'Recup.';

  /// Clave para emparejar alumnos por nombre entre hojas y con la base:
  /// sin mayúsculas ni espacios de más ("  García   Luis" = "garcía luis").
  static String clave(String nombre) =>
      nombre.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static DatosExcel leer(List<int> bytes) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw const ServicioException('El archivo no es un Excel (.xlsx) válido');
    }
    if (excel.tables.isEmpty) {
      throw const ServicioException('El archivo no tiene hojas');
    }

    final advertencias = <String>[];
    final hojaAl = excel.tables[hojaAlumnos] ?? excel.tables.values.first;
    final asist = excel.tables[hojaAsistencia];
    final notas = excel.tables[hojaNotas];

    return DatosExcel(
      alumnos: _leerAlumnos(hojaAl),
      asistencias: asist == null ? const [] : _leerAsistencias(asist, advertencias),
      evaluaciones: notas == null ? const [] : _leerNotas(notas, advertencias),
      advertencias: advertencias,
    );
  }

  // ---------- Alumnos ----------

  static List<FilaAlumno> _leerAlumnos(Sheet hoja) {
    final filas = <FilaAlumno>[];
    for (var i = 0; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];
      final nombre = texto(_celda(fila, 0));
      final telefono = texto(_celda(fila, 1));
      if (nombre.isEmpty && telefono.isEmpty) continue;
      // Encabezado: primera fila sin ningún dígito en la columna del teléfono.
      if (i == 0 && !RegExp(r'\d').hasMatch(telefono)) continue;
      filas.add(FilaAlumno(fila: i + 1, nombre: nombre, telefono: telefono));
    }
    return filas;
  }

  // ---------- Asistencia: Alumno | 07/11/2026 | 08/11/2026 ... ----------

  static List<FilaAsistencia> _leerAsistencias(Sheet hoja, List<String> adv) {
    if (hoja.rows.isEmpty) return const [];
    final encabezado = hoja.rows.first;
    final fechas = <int, String>{}; // columna → fecha ISO
    for (var c = 1; c < encabezado.length; c++) {
      final iso = fechaIso(encabezado[c]);
      if (iso != null) fechas[c] = iso;
    }

    final resultado = <FilaAsistencia>[];
    for (var i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];
      final nombre = texto(_celda(fila, 0));
      if (nombre.isEmpty) continue;
      fechas.forEach((col, fecha) {
        final codigo = texto(_celda(fila, col)).toUpperCase();
        if (codigo.isEmpty) return;
        final estado = EstadoAsistencia.values
            .where((e) => e.codigo == codigo)
            .firstOrNull;
        if (estado == null) {
          adv.add('Asistencia, fila ${i + 1}: "$codigo" no es P, A, T ni J');
        } else {
          resultado.add(FilaAsistencia(nombre: nombre, fecha: fecha, estado: estado));
        }
      });
    }
    return resultado;
  }

  // ---------- Notas: Alumno | Parcial 1 (07/11/2026) | Recup. | ... ----------

  static List<EvaluacionLeida> _leerNotas(Sheet hoja, List<String> adv) {
    if (hoja.rows.isEmpty) return const [];
    final encabezado = hoja.rows.first;
    final evaluaciones = <EvaluacionLeida>[];
    final columnas = <int, EvaluacionLeida>{}; // columna de la nota → evaluación

    for (var c = 1; c < encabezado.length; c++) {
      final titulo = texto(encabezado[c]);
      if (titulo.isEmpty || titulo == tituloRecuperatorio) continue;
      final m = RegExp(r'^(.*?)\s*\((\d{1,2}/\d{1,2}/\d{4})\)$').firstMatch(titulo);
      final nombre = (m?.group(1) ?? titulo).trim();
      final fecha = (m == null ? null : _isoDesdeTexto(m.group(2)!)) ??
          Formato.fechaIso(DateTime.now());
      final tieneRecup = texto(_celda(encabezado, c + 1)) == tituloRecuperatorio;
      final e = EvaluacionLeida(nombre: nombre, fecha: fecha, columnaRecup: tieneRecup ? c + 1 : null);
      evaluaciones.add(e);
      columnas[c] = e;
    }

    for (var i = 1; i < hoja.rows.length; i++) {
      final fila = hoja.rows[i];
      final alumno = texto(_celda(fila, 0));
      if (alumno.isEmpty) continue;
      columnas.forEach((col, e) {
        final nota = _nota(_celda(fila, col), i, adv);
        final recup = e.columnaRecup == null
            ? null
            : _nota(_celda(fila, e.columnaRecup!), i, adv);
        if (nota != null || recup != null) {
          e.notas.add(NotaLeida(alumno: alumno, nota: nota, recuperatorio: recup));
        }
      });
    }
    return evaluaciones;
  }

  static double? _nota(Data? celda, int fila, List<String> adv) {
    final v = celda?.value;
    final double? n = switch (v) {
      IntCellValue(:final value) => value.toDouble(),
      DoubleCellValue(:final value) => value,
      _ => Formato.leerNota(texto(celda)),
    };
    if (n == null) return null;
    if (n.isNaN || n < 1 || n > 10) {
      adv.add('Notas, fila ${fila + 1}: "${texto(celda)}" no es una nota de 1 a 10');
      return null;
    }
    return n;
  }

  // ---------- auxiliares ----------

  static Data? _celda(List<Data?> fila, int col) =>
      col < fila.length ? fila[col] : null;

  /// Texto de una celda. Los números enteros guardados como decimal en Excel
  /// (3794123456.0) se devuelven sin ".0" para no romper los teléfonos.
  static String texto(Data? celda) {
    final v = celda?.value;
    final t = switch (v) {
      null => '',
      IntCellValue(:final value) => value.toString(),
      DoubleCellValue(:final value) => value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString(),
      DateCellValue(:final year, :final month, :final day) =>
        Formato.fecha(Formato.fechaIso(DateTime(year, month, day))),
      DateTimeCellValue(:final year, :final month, :final day) =>
        Formato.fecha(Formato.fechaIso(DateTime(year, month, day))),
      _ => v.toString(),
    };
    return t.trim();
  }

  /// Fecha de un encabezado: texto "07/11/2026" o celda con formato fecha
  /// (si el archivo se editó en Excel o Google Sheets).
  static String? fechaIso(Data? celda) {
    final v = celda?.value;
    return switch (v) {
      DateCellValue(:final year, :final month, :final day) =>
        Formato.fechaIso(DateTime(year, month, day)),
      DateTimeCellValue(:final year, :final month, :final day) =>
        Formato.fechaIso(DateTime(year, month, day)),
      _ => _isoDesdeTexto(texto(celda)),
    };
  }

  static String? _isoDesdeTexto(String t) {
    final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t.trim());
    if (m == null) return null;
    final d = int.parse(m.group(1)!), mes = int.parse(m.group(2)!), a = int.parse(m.group(3)!);
    final f = DateTime(a, mes, d);
    if (f.day != d || f.month != mes) return null; // fecha inexistente (31/02)
    return Formato.fechaIso(f);
  }
}

class DatosExcel {
  final List<FilaAlumno> alumnos;
  final List<FilaAsistencia> asistencias;
  final List<EvaluacionLeida> evaluaciones;
  final List<String> advertencias;

  const DatosExcel({
    required this.alumnos,
    required this.asistencias,
    required this.evaluaciones,
    required this.advertencias,
  });
}

class FilaAlumno {
  final int fila;
  final String nombre;
  final String telefono;
  const FilaAlumno({required this.fila, required this.nombre, required this.telefono});
}

class FilaAsistencia {
  final String nombre;
  final String fecha; // ISO
  final EstadoAsistencia estado;
  const FilaAsistencia({required this.nombre, required this.fecha, required this.estado});
}

class EvaluacionLeida {
  final String nombre;
  final String fecha; // ISO
  final int? columnaRecup;
  final List<NotaLeida> notas = [];
  EvaluacionLeida({required this.nombre, required this.fecha, this.columnaRecup});
}

class NotaLeida {
  final String alumno;
  final double? nota;
  final double? recuperatorio;
  const NotaLeida({required this.alumno, this.nota, this.recuperatorio});
}
