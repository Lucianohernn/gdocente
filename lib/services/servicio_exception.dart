/// Error de regla de negocio con un mensaje apto para mostrar al usuario.
class ServicioException implements Exception {
  final String mensaje;
  const ServicioException(this.mensaje);

  @override
  String toString() => mensaje;
}
