/// Conversión de fechas y números entre la base (formato ISO, punto decimal)
/// y lo que ve el docente (dd/MM/yyyy, coma decimal).
class Formato {
  Formato._();

  /// DateTime → "2026-11-07" (formato que se guarda: ordena bien como texto).
  static String fechaIso(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${_dos(f.month)}-${_dos(f.day)}';

  /// "2026-11-07" → DateTime
  static DateTime desdeIso(String iso) => DateTime.parse(iso);

  /// "2026-11-07" → "07/11/2026"
  static String fecha(String iso) {
    final f = desdeIso(iso);
    return '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
  }

  /// "2026-11-07" → "07/11"
  static String fechaCorta(String iso) {
    final f = desdeIso(iso);
    return '${_dos(f.day)}/${_dos(f.month)}';
  }

  /// 7.5 → "7,5" · 8.0 → "8" · 6.25 → "6,25"
  static String nota(double n) {
    final texto = n == n.roundToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return texto.replaceAll('.', ',');
  }

  /// 85.714 → "86%"
  static String porcentaje(double p) => '${p.round()}%';

  /// Interpreta lo que escribe el docente: "7,5" o "7.5". Vacío → null.
  /// Devuelve NaN si el texto no es un número (para que el validador lo marque).
  static double? leerNota(String texto) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t) ?? double.nan;
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}
