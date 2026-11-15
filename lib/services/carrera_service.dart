import '../dao/carrera_dao.dart';
import '../models/carrera_model.dart';
import 'servicio_exception.dart';

/// Reglas de negocio de carreras. Las pantallas solo hablan con este servicio.
class CarreraService {
  final _dao = CarreraDao();

  Future<List<CarreraModel>> listar() => _dao.listar();

  Future<void> guardar(CarreraModel carrera) async {
    final nombre = carrera.nombre.trim();
    if (nombre.isEmpty) {
      throw const ServicioException('El nombre es obligatorio');
    }
    if (await _dao.existeNombre(nombre, excluirId: carrera.id)) {
      throw const ServicioException('Ya existe una carrera con ese nombre');
    }
    final limpia = carrera.copyWith(nombre: nombre);
    if (carrera.id == null) {
      await _dao.insertar(limpia);
    } else {
      await _dao.actualizar(limpia);
    }
  }

  Future<void> eliminar(CarreraModel carrera) async {
    if (carrera.cantidadMaterias > 0) {
      throw const ServicioException(
          'No se puede eliminar: la carrera tiene materias cargadas');
    }
    await _dao.eliminar(carrera.id!);
  }
}
