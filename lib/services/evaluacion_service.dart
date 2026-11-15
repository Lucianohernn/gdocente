import '../dao/evaluacion_dao.dart';
import '../dao/nota_dao.dart';
import '../models/evaluacion_model.dart';
import '../models/nota_model.dart';
import 'servicio_exception.dart';

class EvaluacionService {
  static const double notaMinima = 1;
  static const double notaMaxima = 10;

  final _dao = EvaluacionDao();
  final _notaDao = NotaDao();

  Future<List<EvaluacionModel>> listarPorMateria(int materiaId) =>
      _dao.listarPorMateria(materiaId);

  Future<void> guardar(EvaluacionModel evaluacion) async {
    final nombre = evaluacion.nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nombre.isEmpty) {
      throw const ServicioException('El nombre es obligatorio');
    }
    if (await _dao.existeNombre(evaluacion.materiaId, nombre,
        excluirId: evaluacion.id)) {
      throw const ServicioException('Ya hay una evaluación con ese nombre');
    }
    final limpia = evaluacion.copyWith(nombre: nombre);
    if (evaluacion.id == null) {
      await _dao.insertar(limpia);
    } else {
      await _dao.actualizar(limpia);
    }
  }

  Future<void> eliminar(EvaluacionModel evaluacion) =>
      _dao.eliminar(evaluacion.id!);

  Future<Map<int, NotaModel>> notasDe(EvaluacionModel evaluacion) =>
      _notaDao.listarPorEvaluacion(evaluacion.id!);

  /// Valida y guarda la planilla completa de notas de una evaluación.
  /// Se permite recuperatorio sin nota original (el alumno faltó al examen).
  Future<void> guardarNotas(List<NotaModel> notas) async {
    for (final n in notas) {
      if (!notaValida(n.nota) || !notaValida(n.recuperatorio)) {
        throw const ServicioException('Las notas deben estar entre 1 y 10');
      }
    }
    await _notaDao.guardarPlanilla(notas);
  }

  /// null (sin nota) es válido; NaN (texto no numérico) no.
  static bool notaValida(double? n) =>
      n == null || (!n.isNaN && n >= notaMinima && n <= notaMaxima);
}
