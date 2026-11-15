import '../dao/asistencia_dao.dart';
import '../models/asistencia_model.dart';
import '../utils/formato.dart';
import 'servicio_exception.dart';

class AsistenciaService {
  final _dao = AsistenciaDao();

  Future<Map<int, EstadoAsistencia>> estadosDelDia(int materiaId, DateTime dia) =>
      _dao.estadosDelDia(materiaId, Formato.fechaIso(dia));

  Future<List<String>> fechasConRegistro(int materiaId) =>
      _dao.fechasConRegistro(materiaId);

  Future<void> guardarDia(DateTime dia, Map<int, EstadoAsistencia?> estados) async {
    final hoy = DateTime.now();
    if (dia.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
      throw const ServicioException('No se puede tomar asistencia de un día futuro');
    }
    await _dao.guardarDia(Formato.fechaIso(dia), estados);
  }

  Future<void> eliminarDia(int materiaId, DateTime dia) =>
      _dao.eliminarDia(materiaId, Formato.fechaIso(dia));
}
