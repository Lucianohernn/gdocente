class CarreraModel {
  final int? id;
  final String nombre;

  /// Dato calculado (no es columna): cantidad de materias de la carrera.
  final int cantidadMaterias;

  const CarreraModel({this.id, required this.nombre, this.cantidadMaterias = 0});

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
      };

  factory CarreraModel.fromMap(Map<String, dynamic> map) => CarreraModel(
        id: map['id'] as int?,
        nombre: map['nombre'] as String,
        cantidadMaterias: (map['cantidad_materias'] as int?) ?? 0,
      );

  CarreraModel copyWith({int? id, String? nombre}) => CarreraModel(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        cantidadMaterias: cantidadMaterias,
      );
}
