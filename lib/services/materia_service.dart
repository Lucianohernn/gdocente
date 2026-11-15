import '../dao/materia_dao.dart';
import '../models/materia_model.dart';
import 'servicio_exception.dart';

class MateriaService {
  final _dao = MateriaDao();

  Future<List<MateriaModel>> listarPorCarrera(int carreraId) =>
      _dao.listarPorCarrera(carreraId);

  Future<void> guardar(MateriaModel materia) async {
    final nombre = materia.nombre.trim();
    if (nombre.isEmpty) {
      throw const ServicioException('El nombre es obligatorio');
    }
    if (materia.anio < 1 || materia.anio > 9) {
      throw const ServicioException('El año debe estar entre 1 y 9');
    }
    if (await _dao.existe(materia.carreraId, nombre, materia.anio,
        excluirId: materia.id)) {
      throw const ServicioException(
          'Esa materia ya existe para ese año de la carrera');
    }
    final limpia = materia.copyWith(nombre: nombre);
    if (materia.id == null) {
      await _dao.insertar(limpia);
    } else {
      await _dao.actualizar(limpia);
    }
  }

  Future<void> eliminar(MateriaModel materia) async {
    if (materia.cantidadAlumnos > 0) {
      throw const ServicioException(
          'No se puede eliminar: la materia tiene alumnos activos');
    }
    await _dao.eliminar(materia.id!);
  }
}
