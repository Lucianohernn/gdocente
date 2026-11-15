import '../dao/alumno_dao.dart';
import '../models/alumno_model.dart';
import '../utils/telefono.dart';
import 'servicio_exception.dart';

class AlumnoService {
  final _dao = AlumnoDao();

  Future<List<AlumnoModel>> listarActivos(int materiaId) =>
      _dao.listarActivosPorMateria(materiaId);

  /// Alta o modificación. Normaliza el teléfono y valida que no se repita
  /// dentro de la misma materia (regla de negocio: vive acá, no en la pantalla).
  Future<void> guardar(AlumnoModel alumno) async {
    final nombre = alumno.nombreCompleto.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nombre.length < 3) {
      throw const ServicioException('Ingresá el nombre completo');
    }
    final telefono = Telefono.normalizar(alumno.telefono);
    if (telefono == null) {
      throw const ServicioException('Teléfono inválido. ${Telefono.ayuda}');
    }
    if (await _dao.existeTelefonoEnMateria(alumno.materiaId, telefono,
        excluirId: alumno.id)) {
      throw const ServicioException(
          'Ya hay un alumno activo con ese teléfono en esta materia');
    }

    final limpio = alumno.copyWith(nombreCompleto: nombre, telefono: telefono);
    if (alumno.id == null) {
      await _dao.insertar(limpio);
    } else {
      await _dao.actualizar(limpio);
    }
  }

  Future<void> darDeBaja(AlumnoModel alumno) => _dao.darDeBaja(alumno.id!);

  /// Reactiva un alumno dado de baja. Aplica la misma regla que el alta: si
  /// mientras tanto se agregó otro alumno activo con el mismo teléfono (por
  /// ejemplo, al importar un Excel), no se reactiva para no duplicarlo.
  Future<void> deshacerBaja(AlumnoModel alumno) async {
    if (await _dao.existeTelefonoEnMateria(alumno.materiaId, alumno.telefono,
        excluirId: alumno.id)) {
      throw ServicioException(
          'No se puede deshacer: ya hay otro alumno activo con el teléfono '
          'de ${alumno.nombreCompleto} en esta materia');
    }
    await _dao.reactivar(alumno.id!);
  }
}
