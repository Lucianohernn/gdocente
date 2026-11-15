/// Utilidades para teléfonos de Argentina en formato WhatsApp (wa.me).
///
/// wa.me exige el número en formato internacional, solo dígitos, sin "+",
/// sin el 0 del código de área y sin el 15. Para celulares de Argentina:
///   54 (país) + 9 (celular) + área sin 0 + número sin 15  →  549 379 4123456
///
/// (Corrección respecto del tutorial: el tip de la Etapa 6 afirma que wa.me
/// "no depende de un formato de número específico", pero sí depende.)
class Telefono {
  Telefono._();

  static const String ayuda =
      'Código de área sin 0 y número sin 15. Ej: 379 4123456';

  /// Devuelve el número normalizado (549XXXXXXXXXX) o null si no es válido.
  static String? normalizar(String? entrada) {
    if (entrada == null) return null;
    var d = entrada.replaceAll(RegExp(r'\D'), ''); // solo dígitos

    if (d.startsWith('00')) d = d.substring(2); // 0054...
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1); // 0379...

    if (d.length == 10) return '549$d'; // 3794123456
    if (d.length == 12 && d.startsWith('54')) {
      return '549${d.substring(2)}'; // 543794123456 (sin el 9)
    }
    if (d.length == 13 && d.startsWith('549')) return d; // ya normalizado
    return null;
  }

  static String? validar(String? entrada) {
    if (entrada == null || entrada.trim().isEmpty) {
      return 'El teléfono es obligatorio';
    }
    if (normalizar(entrada) == null) return 'Teléfono inválido. $ayuda';
    return null;
  }

  /// Para mostrar en pantalla: 5493794123456 → +54 9 379 412-3456
  static String formatear(String normalizado) {
    if (normalizado.length != 13 || !normalizado.startsWith('549')) {
      return normalizado;
    }
    final local = normalizado.substring(3); // 10 dígitos
    return '+54 9 ${local.substring(0, 3)} ${local.substring(3, 6)}-${local.substring(6)}';
  }

  /// Para precargar el campo al editar: 5493794123456 → 3794123456
  static String paraEditar(String normalizado) =>
      normalizado.startsWith('549') && normalizado.length == 13
          ? normalizado.substring(3)
          : normalizado;
}
