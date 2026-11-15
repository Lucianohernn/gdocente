class EvaluacionModel {
  final int? id;
  final int materiaId;
  final String nombre; // Ej: "Parcial 1", "TP 2"
  final String fecha; // yyyy-MM-dd

  /// Dato calculado (no es columna): cantidad de alumnos con nota cargada.
  final int cantidadNotas;

  const EvaluacionModel({
    this.id,
    required this.materiaId,
    required this.nombre,
    required this.fecha,
    this.cantidadNotas = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'materia_id': materiaId,
        'nombre': nombre,
        'fecha': fecha,
      };

  factory EvaluacionModel.fromMap(Map<String, dynamic> map) => EvaluacionModel(
        id: map['id'] as int?,
        materiaId: map['materia_id'] as int,
        nombre: map['nombre'] as String,
        fecha: map['fecha'] as String,
        cantidadNotas: (map['cantidad_notas'] as int?) ?? 0,
      );

  EvaluacionModel copyWith({String? nombre, String? fecha}) => EvaluacionModel(
        id: id,
        materiaId: materiaId,
        nombre: nombre ?? this.nombre,
        fecha: fecha ?? this.fecha,
        cantidadNotas: cantidadNotas,
      );
}
