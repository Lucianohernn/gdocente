class MateriaModel {
  final int? id;
  final int carreraId;
  final String nombre;
  final int anio; // año / nivel dentro de la carrera (1, 2, 3...)

  /// Dato calculado (no es columna): cantidad de alumnos activos.
  final int cantidadAlumnos;

  const MateriaModel({
    this.id,
    required this.carreraId,
    required this.nombre,
    required this.anio,
    this.cantidadAlumnos = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'carrera_id': carreraId,
        'nombre': nombre,
        'anio': anio,
      };

  factory MateriaModel.fromMap(Map<String, dynamic> map) => MateriaModel(
        id: map['id'] as int?,
        carreraId: map['carrera_id'] as int,
        nombre: map['nombre'] as String,
        anio: map['anio'] as int,
        cantidadAlumnos: (map['cantidad_alumnos'] as int?) ?? 0,
      );

  MateriaModel copyWith({int? id, String? nombre, int? anio}) => MateriaModel(
        id: id ?? this.id,
        carreraId: carreraId,
        nombre: nombre ?? this.nombre,
        anio: anio ?? this.anio,
        cantidadAlumnos: cantidadAlumnos,
      );
}
