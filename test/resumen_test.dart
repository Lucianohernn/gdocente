// Pruebas del Hito 3: cálculo del resumen, mensaje de WhatsApp y formatos.
// Ejecutar con: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:gdocente/models/alumno_model.dart';
import 'package:gdocente/models/asistencia_model.dart';
import 'package:gdocente/models/evaluacion_model.dart';
import 'package:gdocente/models/materia_model.dart';
import 'package:gdocente/models/nota_model.dart';
import 'package:gdocente/services/evaluacion_service.dart';
import 'package:gdocente/services/resumen_academico.dart';
import 'package:gdocente/services/whatsapp_service.dart';
import 'package:gdocente/utils/formato.dart';

AsistenciaModel asis(String fecha, EstadoAsistencia e) =>
    AsistenciaModel(alumnoId: 1, fecha: fecha, estado: e);

const parcial1 = EvaluacionModel(
    id: 1, materiaId: 1, nombre: 'Parcial 1', fecha: '2026-05-10');
const tp =
    EvaluacionModel(id: 2, materiaId: 1, nombre: 'TP 1', fecha: '2026-04-01');
const parcial2 = EvaluacionModel(
    id: 3, materiaId: 1, nombre: 'Parcial 2', fecha: '2026-06-20');

void main() {
  group('Asistencia', () {
    test('tardes cuentan como presentes y las justificadas no cuentan', () {
      final r = ResumenAcademico.calcular(
        asistencias: [
          asis('2026-03-01', EstadoAsistencia.presente),
          asis('2026-03-02', EstadoAsistencia.presente),
          asis('2026-03-03', EstadoAsistencia.tarde),
          asis('2026-03-04', EstadoAsistencia.ausente),
          asis('2026-03-05', EstadoAsistencia.justificada),
        ],
        evaluaciones: const [],
        notas: const [],
      );
      expect(r.clasesAsistidas, 3);
      expect(r.clasesComputables, 4);
      expect(r.porcentajeAsistencia, 75);
    });

    test('75% exacto es regular; menos queda en riesgo', () {
      const justo = ResumenAcademico(presentes: 3, ausentes: 1);
      expect(justo.asistenciaBaja, isFalse);
      expect(justo.enRiesgo, isFalse);

      const bajo = ResumenAcademico(presentes: 2, ausentes: 1);
      expect(bajo.asistenciaBaja, isTrue);
      expect(bajo.enRiesgo, isTrue);

      // Sin clases cargadas no se marca riesgo.
      expect(const ResumenAcademico().enRiesgo, isFalse);
    });

    test('sin clases registradas el porcentaje es null', () {
      final r = ResumenAcademico.calcular(
          asistencias: const [], evaluaciones: const [], notas: const []);
      expect(r.porcentajeAsistencia, isNull);
      expect(r.sinDatos, isTrue);
    });
  });

  group('Notas', () {
    test('el recuperatorio reemplaza la nota y el promedio usa la final', () {
      final r = ResumenAcademico.calcular(
        asistencias: const [],
        evaluaciones: const [parcial1, tp, parcial2],
        notas: const [
          NotaModel(evaluacionId: 1, alumnoId: 1, nota: 4, recuperatorio: 7),
          NotaModel(evaluacionId: 2, alumnoId: 1, nota: 9),
          NotaModel(evaluacionId: 3, alumnoId: 1, nota: 5),
        ],
      );
      expect(r.promedio, closeTo(7, 0.001)); // (7 + 9 + 5) / 3
      expect(r.aRecuperar.map((n) => n.evaluacion), ['Parcial 2']);
      // Ordenadas por fecha: TP 1, Parcial 1, Parcial 2
      expect(
          r.notas.map((n) => n.evaluacion), ['TP 1', 'Parcial 1', 'Parcial 2']);
      expect(r.notas[1].recuperada, isTrue);
    });

    test('evaluaciones sin nota no cuentan en el promedio', () {
      final r = ResumenAcademico.calcular(
        asistencias: const [],
        evaluaciones: const [parcial1, parcial2],
        notas: const [NotaModel(evaluacionId: 1, alumnoId: 1, nota: 8)],
      );
      expect(r.promedio, 8);
      expect(r.aRecuperar, isEmpty);
    });

    test('un 6 aprueba y un 5,99 no', () {
      final r = ResumenAcademico.calcular(
        asistencias: const [],
        evaluaciones: const [parcial1, parcial2],
        notas: const [
          NotaModel(evaluacionId: 1, alumnoId: 1, nota: 6),
          NotaModel(evaluacionId: 3, alumnoId: 1, nota: 5.99),
        ],
      );
      expect(r.aRecuperar.single.evaluacion, 'Parcial 2');
    });

    test('validación de notas: 1 a 10, vacío permitido', () {
      expect(EvaluacionService.notaValida(null), isTrue);
      expect(EvaluacionService.notaValida(1), isTrue);
      expect(EvaluacionService.notaValida(10), isTrue);
      expect(EvaluacionService.notaValida(0), isFalse);
      expect(EvaluacionService.notaValida(10.5), isFalse);
      expect(EvaluacionService.notaValida(Formato.leerNota('abc')), isFalse);
    });
  });

  group('Formato', () {
    test('notas con coma decimal', () {
      expect(Formato.nota(8), '8');
      expect(Formato.nota(7.5), '7,5');
      expect(Formato.nota(6.25), '6,25');
      expect(Formato.leerNota('7,5'), 7.5);
      expect(Formato.leerNota(' '), isNull);
    });

    test('fechas', () {
      expect(Formato.fechaIso(DateTime(2026, 3, 5)), '2026-03-05');
      expect(Formato.fecha('2026-03-05'), '05/03/2026');
    });
  });

  group('Mensaje de WhatsApp', () {
    const alumno = AlumnoModel(
        id: 1,
        materiaId: 1,
        nombreCompleto: 'Ana Pérez',
        telefono: '5493794123456',
        fechaAlta: '2026-03-01');
    const materia =
        MateriaModel(id: 1, carreraId: 1, nombre: 'Laboratorio II', anio: 2);
    final service = WhatsAppService();

    test('sin datos, mensaje simple', () {
      final m =
          service.mensajeInicial(alumno, materia, const ResumenAcademico());
      expect(
          m,
          startsWith(
              'Hola Ana! Te escribo por la materia Laboratorio II (2° año).'));
      expect(m, isNot(contains('situación')));
    });

    test('con datos, incluye asistencia, promedio y a recuperar', () {
      final r = ResumenAcademico.calcular(
        asistencias: [
          asis('2026-03-01', EstadoAsistencia.presente),
          asis('2026-03-02', EstadoAsistencia.ausente),
        ],
        evaluaciones: const [parcial1, parcial2],
        notas: const [
          NotaModel(evaluacionId: 1, alumnoId: 1, nota: 8),
          NotaModel(evaluacionId: 3, alumnoId: 1, nota: 4),
        ],
      );
      final m = service.mensajeInicial(alumno, materia, r);
      expect(m, contains('• Asistencia: 50% (1 de 2 clases)'));
      expect(m, contains('• Promedio: 6'));
      expect(m, contains('• A recuperar: Parcial 2 (4)'));
      expect(m, endsWith('Saludos,\nTu docente'));
    });

    test('firma con el nombre del docente si está configurado', () {
      final m = service.mensajeInicial(
          alumno, materia, const ResumenAcademico(), '  Prof. María Gómez ');
      expect(m, endsWith('Saludos,\nProf. María Gómez'));
    });
  });
}
