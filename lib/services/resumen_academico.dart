import '../models/asistencia_model.dart';
import '../models/evaluacion_model.dart';
import '../models/nota_model.dart';

/// Situación de un alumno en una materia. Es lógica pura (no usa SQLite ni UI),
/// por eso se puede probar con pruebas unitarias.
///
/// Reglas (definidas en el Hito 2):
/// - Asistencia: (presentes + tardes) / (presentes + tardes + ausentes).
///   Las faltas justificadas no cuentan en contra ni a favor.
/// - Nota de cada evaluación: el recuperatorio reemplaza a la nota original.
/// - Promedio: de las evaluaciones que tienen nota.
/// - A recuperar: evaluaciones con nota final menor a [notaAprobacion].
class ResumenAcademico {
  static const double notaAprobacion = 6;

  final int presentes;
  final int ausentes;
  final int tardes;
  final int justificadas;

  /// Evaluaciones con nota final, en orden de fecha.
  final List<NotaDeEvaluacion> notas;

  const ResumenAcademico({
    this.presentes = 0,
    this.ausentes = 0,
    this.tardes = 0,
    this.justificadas = 0,
    this.notas = const [],
  });

  int get clasesComputables => presentes + tardes + ausentes;
  int get clasesAsistidas => presentes + tardes;

  /// null si todavía no hay clases registradas.
  double? get porcentajeAsistencia => clasesComputables == 0
      ? null
      : clasesAsistidas * 100 / clasesComputables;

  double? get promedio => notas.isEmpty
      ? null
      : notas.map((n) => n.notaFinal).reduce((a, b) => a + b) / notas.length;

  List<NotaDeEvaluacion> get aRecuperar =>
      notas.where((n) => n.notaFinal < notaAprobacion).toList();

  bool get sinDatos => clasesComputables == 0 && justificadas == 0 && notas.isEmpty;

  /// Arma el resumen de UN alumno a partir de sus registros.
  factory ResumenAcademico.calcular({
    required Iterable<AsistenciaModel> asistencias,
    required Iterable<EvaluacionModel> evaluaciones,
    required Iterable<NotaModel> notas,
  }) {
    final cuenta = {for (final e in EstadoAsistencia.values) e: 0};
    for (final a in asistencias) {
      cuenta[a.estado] = cuenta[a.estado]! + 1;
    }

    final notaPorEvaluacion = {for (final n in notas) n.evaluacionId: n};
    final ordenadas = evaluaciones.toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final conNota = <NotaDeEvaluacion>[];
    for (final e in ordenadas) {
      final n = notaPorEvaluacion[e.id];
      final finalNota = n?.notaFinal;
      if (n != null && finalNota != null) {
        conNota.add(NotaDeEvaluacion(
          evaluacion: e.nombre,
          notaFinal: finalNota,
          recuperada: n.recuperatorio != null,
        ));
      }
    }

    return ResumenAcademico(
      presentes: cuenta[EstadoAsistencia.presente]!,
      ausentes: cuenta[EstadoAsistencia.ausente]!,
      tardes: cuenta[EstadoAsistencia.tarde]!,
      justificadas: cuenta[EstadoAsistencia.justificada]!,
      notas: conNota,
    );
  }
}

class NotaDeEvaluacion {
  final String evaluacion;
  final double notaFinal;
  final bool recuperada; // true si la nota final viene del recuperatorio

  const NotaDeEvaluacion({
    required this.evaluacion,
    required this.notaFinal,
    this.recuperada = false,
  });
}
