import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'cuenta_google.dart';
import 'servicio_exception.dart';

/// Un backup guardado en Google Drive.
class BackupDrive {
  final String id;
  final DateTime fecha;
  final String origen; // "Android" o "Windows"
  final int bytes;
  const BackupDrive(this.id, this.fecha, this.origen, this.bytes);
}

/// Copia de seguridad de la base en el Google Drive del docente.
///
/// - Carpeta "GDocente backups" en su Drive, con los últimos [conservar].
/// - Automático: una vez por día, al abrir o volver a la app (y en Windows
///   también al cerrarla). Un horario fijo (ej. 3 AM) no es confiable: con la
///   app cerrada Android puede no ejecutarla y la notebook suele estar apagada.
/// - Restaurar reemplaza los datos de este dispositivo por los del backup.
class BackupService extends ChangeNotifier {
  BackupService._();
  static final BackupService instancia = BackupService._();

  static const carpeta = 'GDocente backups';
  static const conservar = 7;
  static const cadaCuanto = Duration(hours: 24);

  static const _kEmail = 'backup_email';
  static const _kUltimo = 'backup_ultimo';
  static const _kError = 'backup_error';
  static const _tipoCarpeta = 'application/vnd.google-apps.folder';

  final CuentaGoogle _cuenta = CuentaGoogle();
  SharedPreferences? _prefs;

  String? _email;
  DateTime? _ultimo;
  String? _error;
  bool _ocupado = false;

  /// Cuenta conectada (null si nunca se conectó o se desconectó).
  String? get email => _email;
  bool get conectado => _email != null;
  DateTime? get ultimoBackup => _ultimo;

  /// Problema del último backup automático, para mostrarlo en Ajustes.
  String? get error => _error;
  bool get ocupado => _ocupado;

  Future<void> cargar() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _email = prefs.getString(_kEmail);
    final ms = prefs.getInt(_kUltimo);
    _ultimo = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    _error = prefs.getString(_kError);
  }

  // ---------------------------------------------------------------- cuenta

  Future<void> conectar() => _trabajo(() async {
        final cliente = await _cuenta.conectar();
        try {
          final about =
              await drive.DriveApi(cliente).about.get($fields: 'user');
          _email = about.user?.emailAddress ?? 'Cuenta de Google';
          await _prefs?.setString(_kEmail, _email!);
          await _subir(cliente); // primer backup en el momento
        } finally {
          cliente.close();
        }
      });

  Future<void> desconectar() => _trabajo(() async {
        try {
          await _cuenta.desconectar();
        } finally {
          _email = null;
          _ultimo = null;
          await _prefs?.remove(_kEmail);
          await _prefs?.remove(_kUltimo);
          await _guardarError(null);
        }
      });

  // --------------------------------------------------------------- backups

  /// Botón "Hacer backup ahora".
  Future<void> hacerBackup() => _conCliente(_subir);

  /// Se llama al abrir la app, al volver a ella y (Windows) al cerrarla.
  /// No muestra nada: si falla, deja el aviso en Ajustes.
  Future<void> automaticoSiCorresponde() async {
    if (!conectado || _ocupado) return;
    if (!tocaBackup(_ultimo, DateTime.now())) return;
    try {
      await hacerBackup();
    } catch (e) {
      debugPrint('Backup automático: $e');
    }
  }

  Future<List<BackupDrive>> listar() async {
    final cliente = await _clienteOError();
    try {
      final api = drive.DriveApi(cliente);
      final id = await _idCarpeta(api, crear: false);
      return id == null ? [] : await _listar(api, id);
    } catch (e) {
      throw _traducir(e);
    } finally {
      cliente.close();
    }
  }

  /// Reemplaza los datos de este dispositivo por los del backup. Antes deja
  /// una copia de los datos actuales en "gdocente-antes-de-restaurar.db".
  Future<void> restaurar(BackupDrive backup) => _conCliente((cliente) async {
        final media = await drive.DriveApi(cliente).files.get(backup.id,
            downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final bytes = <int>[];
        await for (final parte in media.stream) {
          bytes.addAll(parte);
        }
        if (!esBaseSqlite(bytes)) {
          throw const ServicioException('El archivo del backup está dañado.');
        }

        final db = AppDatabase.instance;
        final ruta = await db.rutaArchivo();
        await db.cerrar();
        final actual = File(ruta);
        if (await actual.exists()) {
          await actual.copy(p.join(p.dirname(ruta), 'gdocente-antes-de-restaurar.db'));
        }
        // Restos del modo WAL de la base anterior: no deben mezclarse.
        for (final extra in ['-wal', '-shm', '-journal']) {
          final f = File('$ruta$extra');
          if (await f.exists()) await f.delete();
        }
        await actual.writeAsBytes(bytes, flush: true);
        await db.database; // reabre (y migra si el backup es de una versión vieja)
      });

  // ------------------------------------------------------------- internos

  Future<void> _subir(http.Client cliente) async {
    final api = drive.DriveApi(cliente);
    final db = AppDatabase.instance;
    // Vuelca al archivo principal lo pendiente del modo WAL, así la copia
    // tiene todo lo guardado hasta este momento.
    await (await db.database).rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final bytes = await File(await db.rutaArchivo()).readAsBytes();

    final carpetaId = (await _idCarpeta(api, crear: true))!;
    final ahora = DateTime.now();
    final origen = Platform.isWindows ? 'Windows' : 'Android';
    await api.files.create(
      drive.File()
        ..name = nombreArchivo(ahora, origen)
        ..parents = [carpetaId]
        ..appProperties = {'origen': origen},
      uploadMedia: drive.Media(Stream.value(bytes), bytes.length,
          contentType: 'application/x-sqlite3'),
    );

    final viejos = aBorrar(await _listar(api, carpetaId), conservar);
    for (final b in viejos) {
      await api.files.delete(b.id);
    }

    _ultimo = ahora;
    await _prefs?.setInt(_kUltimo, ahora.millisecondsSinceEpoch);
    await _guardarError(null);
  }

  Future<String?> _idCarpeta(drive.DriveApi api, {required bool crear}) async {
    final r = await api.files.list(
      q: "name = '$carpeta' and mimeType = '$_tipoCarpeta' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    final id = r.files?.firstOrNull?.id;
    if (id != null || !crear) return id;
    final nueva = await api.files.create(drive.File()
      ..name = carpeta
      ..mimeType = _tipoCarpeta);
    return nueva.id;
  }

  Future<List<BackupDrive>> _listar(drive.DriveApi api, String carpetaId) async {
    final r = await api.files.list(
      q: "'$carpetaId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      pageSize: 100,
      $fields: 'files(id,createdTime,size,appProperties)',
    );
    return [
      for (final f in r.files ?? <drive.File>[])
        BackupDrive(
          f.id!,
          (f.createdTime ?? DateTime(2000)).toLocal(),
          f.appProperties?['origen'] ?? '',
          int.tryParse(f.size ?? '') ?? 0,
        ),
    ];
  }

  Future<http.Client> _clienteOError() async {
    final cliente = await _cuenta.clienteSilencioso();
    if (cliente != null) return cliente;
    throw const ServicioException(
        'Hay que volver a conectar la cuenta de Google en Ajustes.');
  }

  /// Obtiene la conexión, ejecuta [accion] y guarda el error si lo hay.
  Future<void> _conCliente(Future<void> Function(http.Client) accion) =>
      _trabajo(() async {
        final cliente = await _clienteOError();
        try {
          await accion(cliente);
        } finally {
          cliente.close();
        }
      });

  Future<void> _trabajo(Future<void> Function() tarea) async {
    if (_ocupado) {
      throw const ServicioException('Ya hay un backup en curso, esperá un momento.');
    }
    _ocupado = true;
    notifyListeners();
    try {
      await tarea();
    } catch (e) {
      final error = _traducir(e);
      if (conectado) await _guardarError(error.mensaje);
      throw error;
    } finally {
      _ocupado = false;
      notifyListeners();
    }
  }

  Future<void> _guardarError(String? mensaje) async {
    _error = mensaje;
    if (mensaje == null) {
      await _prefs?.remove(_kError);
    } else {
      await _prefs?.setString(_kError, mensaje);
    }
  }

  /// Mensajes claros para el docente en lugar de errores técnicos.
  static ServicioException _traducir(Object e) {
    if (e is ServicioException) return e;
    debugPrint('Backup: $e');
    if (e is SocketException || e is http.ClientException) {
      return const ServicioException('No hay conexión a internet.');
    }
    if (e is TimeoutException) {
      return const ServicioException('No se completó la conexión con Google.');
    }
    final texto = e.toString();
    if (texto.contains('canceled') || texto.contains('cancelled')) {
      return const ServicioException('Se canceló la conexión con Google.');
    }
    if (texto.contains('401') || texto.contains('invalid_grant')) {
      return const ServicioException(
          'Google pidió volver a conectar la cuenta en Ajustes.');
    }
    return const ServicioException('No se pudo completar el backup. Probá de nuevo.');
  }

  // ------------------------------------------- reglas puras (con tests)

  @visibleForTesting
  static bool tocaBackup(DateTime? ultimo, DateTime ahora) =>
      ultimo == null || ahora.difference(ultimo) >= cadaCuanto;

  /// Los backups que sobran, dejando los [conservar] más nuevos.
  @visibleForTesting
  static List<BackupDrive> aBorrar(List<BackupDrive> todos, int conservar) {
    final orden = [...todos]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return orden.skip(conservar).toList();
  }

  /// Todo archivo SQLite empieza con "SQLite format 3\0".
  @visibleForTesting
  static bool esBaseSqlite(List<int> bytes) {
    const firma = 'SQLite format 3';
    if (bytes.length < 100) return false;
    for (var i = 0; i < firma.length; i++) {
      if (bytes[i] != firma.codeUnitAt(i)) return false;
    }
    return bytes[firma.length] == 0;
  }

  @visibleForTesting
  static String nombreArchivo(DateTime f, String origen) {
    String d(int n) => n.toString().padLeft(2, '0');
    return 'GDocente ${f.year}-${d(f.month)}-${d(f.day)} '
        '${d(f.hour)}.${d(f.minute)} ($origen).db';
  }
}
