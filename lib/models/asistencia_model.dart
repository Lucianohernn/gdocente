/// Estados posibles de una asistencia. El código de una letra es lo que se
/// guarda en la columna `estado` (restringida con CHECK en la base).
enum EstadoAsistencia {
  presente('P', 'Presente'),
  ausente('A', 'Ausente'),
  tarde('T', 'Tarde'),
  justificada('J', 'Justificada');

  final String codigo;
  final String etiqueta;
  const EstadoAsistencia(this.codigo, this.etiqueta);

  static EstadoAsistencia desdeCodigo(String codigo) =>
      values.firstWhere((e) => e.codigo == codigo);
}

class AsistenciaModel {
  final int? id;
  final int alumnoId;
  final String fecha; // yyyy-MM-dd
  final EstadoAsistencia estado;

  const AsistenciaModel({
    this.id,
    required this.alumnoId,
    required this.fecha,
    required this.estado,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'alumno_id': alumnoId,
        'fecha': fecha,
        'estado': estado.codigo,
      };

  factory AsistenciaModel.fromMap(Map<String, dynamic> map) => AsistenciaModel(
        id: map['id'] as int?,
        alumnoId: map['alumno_id'] as int,
        fecha: map['fecha'] as String,
        estado: EstadoAsistencia.desdeCodigo(map['estado'] as String),
      );
}
