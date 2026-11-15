// Pruebas de la lectura de Excel para importar (sin base de datos).
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdocente/models/asistencia_model.dart';
import 'package:gdocente/services/lector_excel.dart';
import 'package:gdocente/services/servicio_exception.dart';

TextCellValue t(String s) => TextCellValue(s);

/// Arma un .xlsx con el mismo formato que genera la exportación de GDocente.
List<int> excelComoExportado() {
  final x = Excel.createExcel();
  x.rename(x.getDefaultSheet()!, 'Resumen');
  x['Resumen'].appendRow([t('Alumno'), t('Asistencia %')]);

  final asis = x['Asistencia'];
  asis.appendRow([t('Alumno'), t('07/11/2026'), t('08/11/2026')]);
  asis.appendRow([t('Ana Pérez'), t('P'), t('T')]);
  asis.appendRow([t('Luis García'), t('A'), t('')]);
  asis.appendRow([]);
  asis.appendRow([t('P = Presente · A = Ausente · T = Tarde · J = Justificada')]);

  final notas = x['Notas'];
  notas.appendRow([t('Alumno'), t('Parcial 1 (05/11/2026)'), t('Recup.'), t('TP 1 (01/10/2026)'), t('Recup.')]);
  notas.appendRow([t('Ana Pérez'), DoubleCellValue(4), DoubleCellValue(7.5), DoubleCellValue(9), null]);
  notas.appendRow([t('Luis García'), DoubleCellValue(8), null, null, null]);

  final al = x['Alumnos'];
  al.appendRow([t('Nombre completo'), t('Teléfono')]);
  al.appendRow([t('Ana Pérez'), t('3794123456')]);
  al.appendRow([t('Luis García'), IntCellValue(3794654321)]);
  return x.encode()!;
}

void main() {
  test('lee alumnos, asistencias y notas del Excel exportado', () {
    final d = LectorExcel.leer(excelComoExportado());

    expect(d.alumnos.map((a) => a.nombre), ['Ana Pérez', 'Luis García']);
    expect(d.alumnos[1].telefono, '3794654321'); // número de Excel → texto

    expect(d.asistencias, hasLength(3)); // la celda vacía y la leyenda se ignoran
    final ana = d.asistencias.where((a) => a.nombre == 'Ana Pérez').toList();
    expect(ana.map((a) => a.fecha), ['2026-11-07', '2026-11-08']);
    expect(ana.map((a) => a.estado), [EstadoAsistencia.presente, EstadoAsistencia.tarde]);

    expect(d.evaluaciones.map((e) => e.nombre), ['Parcial 1', 'TP 1']);
    expect(d.evaluaciones.first.fecha, '2026-11-05');
    final parcial = d.evaluaciones.first.notas;
    expect(parcial.first.nota, 4);
    expect(parcial.first.recuperatorio, 7.5);
    expect(d.evaluaciones[1].notas, hasLength(1)); // Luis no tiene nota del TP
    expect(d.advertencias, isEmpty);
  });

  test('lista simple: columna A nombre, B teléfono, sin otras hojas', () {
    final x = Excel.createExcel();
    final hoja = x[x.getDefaultSheet()!];
    hoja.appendRow([t('Nombre'), t('Celular')]);
    hoja.appendRow([t('Ana Pérez'), DoubleCellValue(3794123456)]);
    hoja.appendRow([]);
    hoja.appendRow([t('Luis García'), t('0379 15 4654321')]);

    final d = LectorExcel.leer(x.encode()!);
    expect(d.alumnos.map((a) => a.nombre), ['Ana Pérez', 'Luis García']);
    expect(d.alumnos.first.telefono, '3794123456'); // sin ".0"
    expect(d.asistencias, isEmpty);
    expect(d.evaluaciones, isEmpty);
  });

  test('avisa códigos de asistencia y notas inválidos', () {
    final x = Excel.createExcel();
    x['Asistencia']
      ..appendRow([t('Alumno'), t('07/11/2026')])
      ..appendRow([t('Ana Pérez'), t('X')]);
    x['Notas']
      ..appendRow([t('Alumno'), t('Parcial 1 (05/11/2026)'), t('Recup.')])
      ..appendRow([t('Ana Pérez'), DoubleCellValue(12), t('7,5')]);

    final d = LectorExcel.leer(x.encode()!);
    expect(d.asistencias, isEmpty);
    expect(d.evaluaciones.single.notas.single.nota, isNull); // 12 descartado
    expect(d.evaluaciones.single.notas.single.recuperatorio, 7.5); // "7,5" ok
    expect(d.advertencias, hasLength(2));
  });

  test('fechas como celda de fecha (archivo editado en Excel/Sheets)', () {
    final x = Excel.createExcel();
    x['Asistencia']
      ..appendRow([t('Alumno'), DateCellValue(year: 2026, month: 3, day: 9)])
      ..appendRow([t('Ana Pérez'), t('j')]);
    final d = LectorExcel.leer(x.encode()!);
    expect(d.asistencias.single.fecha, '2026-03-09');
    expect(d.asistencias.single.estado, EstadoAsistencia.justificada);
  });

  test('el mismo alumno se reconoce aunque cambien mayúsculas o espacios', () {
    expect(LectorExcel.clave('  GARCÍA   Luis '), LectorExcel.clave('García Luis'));
  });

  test('un archivo que no es Excel da un error claro', () {
    expect(() => LectorExcel.leer([1, 2, 3, 4]), throwsA(isA<ServicioException>()));
  });
}
