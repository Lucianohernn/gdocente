class NotaModel {
  final int? id;
  final int evaluacionId;
  final int alumnoId;
  final double? nota; // nota original (1 a 10); null = no rindió
  final double? recuperatorio; // null = no recuperó

  const NotaModel({
    this.id,
    required this.evaluacionId,
    required this.alumnoId,
    this.nota,
    this.recuperatorio,
  });

  /// Nota que cuenta para el promedio: el recuperatorio reemplaza a la original.
  double? get notaFinal => recuperatorio ?? nota;

  bool get vacia => nota == null && recuperatorio == null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'evaluacion_id': evaluacionId,
        'alumno_id': alumnoId,
        'nota': nota,
        'recuperatorio': recuperatorio,
      };

  factory NotaModel.fromMap(Map<String, dynamic> map) => NotaModel(
        id: map['id'] as int?,
        evaluacionId: map['evaluacion_id'] as int,
        alumnoId: map['alumno_id'] as int,
        nota: (map['nota'] as num?)?.toDouble(),
        recuperatorio: (map['recuperatorio'] as num?)?.toDouble(),
      );
}
