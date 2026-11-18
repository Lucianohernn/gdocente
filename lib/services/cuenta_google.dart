import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_config.dart';

/// Conexión con la cuenta de Google del docente, solo para Google Drive.
///
/// El permiso pedido es "drive.file": la app ve únicamente los archivos que
/// ella misma creó (sus backups), nunca el resto del Drive del docente.
///
/// - Android: inicio de sesión del sistema (google_sign_in).
/// - Windows: se abre el navegador para autorizar; el permiso se guarda en
///   la notebook y se renueva solo.
abstract class CuentaGoogle {
  static const permisos = [drive.DriveApi.driveFileScope];

  factory CuentaGoogle() =>
      Platform.isWindows ? _CuentaWindows() : _CuentaAndroid();

  /// Pide al docente que elija la cuenta y autorice. Solo desde un botón.
  Future<http.Client> conectar();

  /// Cliente listo para usar sin mostrar nada, o null si hay que volver a
  /// conectar (por ejemplo, si el docente quitó el permiso desde Google).
  Future<http.Client?> clienteSilencioso();

  Future<void> desconectar();
}

class _CuentaAndroid implements CuentaGoogle {
  static Future<void>? _inicio;

  Future<void> _iniciar() => _inicio ??= GoogleSignIn.instance
      .initialize(serverClientId: GoogleConfig.clienteWeb);

  @override
  Future<http.Client> conectar() async {
    await _iniciar();
    final cuenta = await GoogleSignIn.instance
        .authenticate(scopeHint: CuentaGoogle.permisos);
    final permiso = await cuenta.authorizationClient
        .authorizeScopes(CuentaGoogle.permisos);
    return _ClienteConToken(permiso.accessToken);
  }

  @override
  Future<http.Client?> clienteSilencioso() async {
    await _iniciar();
    final cuenta =
        await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (cuenta == null) return null;
    final permiso = await cuenta.authorizationClient
        .authorizationForScopes(CuentaGoogle.permisos);
    if (permiso == null) return null;
    return _ClienteConToken(permiso.accessToken);
  }

  @override
  Future<void> desconectar() async {
    await _iniciar();
    await GoogleSignIn.instance.disconnect();
  }
}

/// Agrega el token de acceso de Google a cada pedido a Drive.
class _ClienteConToken extends http.BaseClient {
  final String _token;
  final _interno = http.Client();
  _ClienteConToken(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _interno.send(request);
  }

  @override
  void close() => _interno.close();
}

class _CuentaWindows implements CuentaGoogle {
  static const _kCredenciales = 'google_credenciales';
  static final _id = ClientId(
      GoogleConfig.clienteEscritorio, GoogleConfig.secretoEscritorio);

  static const _paginaFinal = '''
<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>GDocente</title></head>
<body style="font-family:Segoe UI,sans-serif;background:#F3F0E8;color:#14182B;
text-align:center;padding-top:80px">
<h1 style="color:#2F4FBF">Listo, GDocente quedó conectado a Google Drive</h1>
<p style="font-size:20px">Ya podés cerrar esta ventana y volver a GDocente.</p>
</body></html>''';

  @override
  Future<http.Client> conectar() async {
    final cliente = await clientViaUserConsent(
      _id,
      CuentaGoogle.permisos,
      (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      customPostAuthPage: _paginaFinal,
    ).timeout(const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException(
            'No se completó la autorización en el navegador.'));
    await _guardar(cliente.credentials);
    cliente.credentialUpdates.listen(_guardar);
    return cliente;
  }

  @override
  Future<http.Client?> clienteSilencioso() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kCredenciales);
    if (json == null) return null;
    final credenciales = AccessCredentials.fromJson(
        jsonDecode(json) as Map<String, dynamic>);
    if (credenciales.refreshToken == null) return null;
    final cliente = autoRefreshingClient(_id, credenciales, http.Client());
    cliente.credentialUpdates.listen(_guardar);
    return cliente;
  }

  Future<void> _guardar(AccessCredentials c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCredenciales, jsonEncode(c.toJson()));
  }

  @override
  Future<void> desconectar() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kCredenciales);
    await prefs.remove(_kCredenciales);
    if (json == null) return;
    // Además de olvidarlo acá, se le avisa a Google que quite el permiso.
    final token = (jsonDecode(json)
        as Map<String, dynamic>)['refreshToken'] as String?;
    if (token == null) return;
    try {
      await http.post(Uri.https('oauth2.googleapis.com', '/revoke'),
          body: {'token': token});
    } catch (_) {
      // Sin internet: igual queda desconectado en esta notebook.
    }
  }
}
