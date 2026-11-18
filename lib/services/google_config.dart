/// Identificadores OAuth del proyecto "gdocente" de Google Cloud.
///
/// No son contraseñas: Google los trata como datos públicos de la app. En las
/// apps de escritorio el "secreto" tampoco es secreto (va dentro del .exe);
/// la seguridad la da que cada docente inicia sesión con su propia cuenta.
class GoogleConfig {
  GoogleConfig._();

  /// Cliente "Aplicación web": en Android google_sign_in lo pide como
  /// serverClientId. El cliente Android (paquete + SHA-1) no se escribe acá:
  /// Google lo reconoce por la firma del APK.
  static const clienteWeb =
      '371008287831-r7jdbnkr7bsb9asno8tdttg88mnlurlj.apps.googleusercontent.com';

  /// Cliente "App de escritorio" (Windows).
  static const clienteEscritorio =
      '371008287831-kqbv50st2457keb93qh2cor5hijm50eu.apps.googleusercontent.com';
  static const secretoEscritorio = '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';
}
