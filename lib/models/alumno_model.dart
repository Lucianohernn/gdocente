class AlumnoModel {
  final int? id;
  final int materiaId;
  final String nombreCompleto;
  final String telefono; // guardado normalizado: 549 + área + número (ej. 5493794123456)
  final String fechaAlta; // ISO 8601
  final int activo; // 1 = activo, 0 = dado de baja (borrado lógico)

  const AlumnoModel({
    this.id,
    required this.materiaId,
    required this.nombreCompleto,
    required this.telefono,
    required this.fechaAlta,
    this.activo = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'materia_id': materiaId,
        'nombre_completo': nombreCompleto,
        'telefono': telefono,
        'fecha_alta': fechaAlta,
        'activo': activo,
      };

  factory AlumnoModel.fromMap(Map<String, dynamic> map) => AlumnoModel(
        id: map['id'] as int?,
        materiaId: map['materia_id'] as int,
        nombreCompleto: map['nombre_completo'] as String,
        telefono: map['telefono'] as String,
        fechaAlta: map['fecha_alta'] as String,
        activo: map['activo'] as int,
      );

  AlumnoModel copyWith({
    int? id,
    String? nombreCompleto,
    String? telefono,
    int? activo,
  }) =>
      AlumnoModel(
        id: id ?? this.id,
        materiaId: materiaId,
        nombreCompleto: nombreCompleto ?? this.nombreCompleto,
        telefono: telefono ?? this.telefono,
        fechaAlta: fechaAlta,
        activo: activo ?? this.activo,
      );
}
