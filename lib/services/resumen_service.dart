import '../dao/asistencia_dao.dart';
import '../dao/evaluacion_dao.dart';
import '../dao/nota_dao.dart';
import '../models/alumno_model.dart';
import 'resumen_academico.dart';

/// Arma los resúmenes de todos los alumnos de una materia con 3 consultas
/// (en lugar de 3 por alumno) y los agrupa en memoria.
class ResumenService {
  final _asistenciaDao = AsistenciaDao();
  final _evaluacionDao = EvaluacionDao();
  final _notaDao = NotaDao();

  Future<Map<int, ResumenAcademico>> deMateria(
      int materiaId, List<AlumnoModel> alumnos) async {
    final asistencias = await _asistenciaDao.listarPorMateria(materiaId);
    final evaluaciones = await _evaluacionDao.listarPorMateria(materiaId);
    final notas = await _notaDao.listarPorMateria(materiaId);

    return {
      for (final a in alumnos)
        a.id!: ResumenAcademico.calcular(
          asistencias: asistencias.where((s) => s.alumnoId == a.id),
          evaluaciones: evaluaciones,
          notas: notas.where((n) => n.alumnoId == a.id),
        ),
    };
  }
}
