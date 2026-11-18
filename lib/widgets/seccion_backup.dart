import 'dart:io';

import 'package:flutter/material.dart';

import '../screens/carreras_screen.dart';
import '../services/backup_service.dart';
import '../utils/app_tema.dart';
import 'ui_helpers.dart';

/// Bloque de Ajustes para la copia de seguridad en Google Drive.
class SeccionBackup extends StatelessWidget {
  const SeccionBackup({super.key});

  static String fechaLegible(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    final hoy = DateTime.now();
    final dia = DateTime(f.year, f.month, f.day);
    final dias = DateTime(hoy.year, hoy.month, hoy.day).difference(dia).inDays;
    final hora = '${d(f.hour)}:${d(f.minute)}';
    if (dias == 0) return 'hoy a las $hora';
    if (dias == 1) return 'ayer a las $hora';
    return 'el ${d(f.day)}/${d(f.month)}/${f.year} a las $hora';
  }

  @override
  Widget build(BuildContext context) {
    final backup = BackupService.instancia;
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: backup,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Copia de seguridad', style: tema.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Guarda tus carreras, alumnos, asistencias y notas en tu '
              'Google Drive. Así no se pierden si cambiás o perdés el '
              '${Platform.isWindows ? 'equipo' : 'teléfono'}.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (backup.conectado)
              _Conectado(backup: backup)
            else
              _BotonGrande(
                icono: Icons.cloud_upload_outlined,
                texto: 'Conectar con Google Drive',
                ocupado: backup.ocupado,
                onPressed: () => _conectar(context),
              ),
          ],
        );
      },
    );
  }

  Future<void> _conectar(BuildContext context) async {
    if (Platform.isWindows) {
      mostrarMensaje(context,
          'Se abre el navegador: elegí tu cuenta y tocá "Continuar".');
    }
    try {
      await BackupService.instancia.conectar();
      if (context.mounted) {
        mostrarMensaje(context, 'Conectado. Ya se hizo el primer backup.');
      }
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, '$e', error: true);
    }
  }
}

class _Conectado extends StatelessWidget {
  final BackupService backup;
  const _Conectado({required this.backup});

  @override
  Widget build(BuildContext context) {
    final app = ColoresApp.of(context);
    final tema = Theme.of(context);
    final ultimo = backup.ultimoBackup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: app.panelDecoracion(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.cloud_done_outlined, color: app.marca),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(backup.email!,
                      style: tema.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                ultimo == null
                    ? 'Todavía no hay backups.'
                    : 'Último backup: ${SeccionBackup.fechaLegible(ultimo)}.',
                style: tema.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Se hace solo una vez por día al usar la app. '
                'Se guardan los últimos ${BackupService.conservar}.',
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: app.textoSecundario),
              ),
              if (backup.error != null) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: app.riesgo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('El último intento falló: ${backup.error}',
                        style: tema.textTheme.bodyMedium
                            ?.copyWith(color: app.riesgo)),
                  ),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BotonGrande(
          icono: Icons.backup_outlined,
          texto: 'Hacer backup ahora',
          ocupado: backup.ocupado,
          onPressed: () => _ahora(context),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: backup.ocupado ? null : () => _restaurar(context),
            icon: const Icon(Icons.restore),
            label: const Text('Recuperar un backup',
                style: TextStyle(fontSize: 16)),
          ),
        ),
        TextButton(
          onPressed: backup.ocupado ? null : () => _desconectar(context),
          child: const Text('Desconectar cuenta de Google'),
        ),
      ],
    );
  }

  Future<void> _ahora(BuildContext context) async {
    try {
      await backup.hacerBackup();
      if (context.mounted) mostrarMensaje(context, 'Backup guardado en Drive');
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, '$e', error: true);
    }
  }

  Future<void> _desconectar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Desconectar Google Drive',
      mensaje: 'Se dejan de hacer backups. Los que ya están en tu Drive '
          'no se borran.',
      textoConfirmar: 'Desconectar',
    );
    if (!ok) return;
    try {
      await backup.desconectar();
    } catch (_) {
      // Queda desconectado igual en este dispositivo.
    }
  }

  Future<void> _restaurar(BuildContext context) async {
    final List<BackupDrive> lista;
    try {
      lista = await backup.listar();
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, '$e', error: true);
      return;
    }
    if (!context.mounted) return;
    if (lista.isEmpty) {
      mostrarMensaje(context, 'Todavía no hay backups en tu Drive.');
      return;
    }

    final elegido = await showDialog<BackupDrive>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿Qué backup querés recuperar?'),
        children: [
          for (final b in lista)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, b),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                '${_mayuscula(SeccionBackup.fechaLegible(b.fecha))}'
                '${b.origen.isEmpty ? '' : '\ndesde ${b.origen == 'Android' ? 'el teléfono' : 'la notebook'}'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
        ],
      ),
    );
    if (elegido == null || !context.mounted) return;

    final equipo = Platform.isWindows ? 'esta notebook' : 'este teléfono';
    final ok = await confirmar(
      context,
      titulo: 'Recuperar backup',
      mensaje: 'Se reemplazan TODOS los datos de $equipo por los del backup '
          '${SeccionBackup.fechaLegible(elegido.fecha)}.\n\n'
          'Lo que cargaste después de esa fecha se pierde.',
      textoConfirmar: 'Recuperar',
    );
    if (!ok || !context.mounted) return;

    try {
      await backup.restaurar(elegido);
      if (!context.mounted) return;
      mostrarMensaje(context, 'Backup recuperado');
      // Las pantallas abiertas tenían los datos viejos: se vuelve al inicio.
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CarrerasScreen()),
          (_) => false);
    } catch (e) {
      if (context.mounted) mostrarMensaje(context, '$e', error: true);
    }
  }

  static String _mayuscula(String s) => s[0].toUpperCase() + s.substring(1);
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool ocupado;
  final VoidCallback onPressed;
  const _BotonGrande(
      {required this.icono,
      required this.texto,
      required this.ocupado,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: ocupado ? null : onPressed,
        icon: ocupado
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5))
            : Icon(icono),
        label: Text(ocupado ? 'Guardando en Drive…' : texto,
            style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
