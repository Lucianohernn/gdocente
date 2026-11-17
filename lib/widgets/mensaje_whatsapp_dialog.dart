import 'package:flutter/material.dart';

import '../models/alumno_model.dart';
import '../models/materia_model.dart';
import '../services/ajustes_service.dart';
import '../services/resumen_academico.dart';
import '../services/servicio_exception.dart';
import '../services/whatsapp_service.dart';
import '../utils/telefono.dart';
import 'ui_helpers.dart';

/// Muestra el mensaje para que el docente lo revise/edite antes de abrir
/// WhatsApp (criterio de privacidad del Hito 1: envío individual y revisado).
Future<void> mostrarMensajeWhatsApp(
  BuildContext context, {
  required AlumnoModel alumno,
  required MateriaModel materia,
  ResumenAcademico? resumen,
}) async {
  final service = WhatsAppService();
  final ctrl = TextEditingController(
      text: service.mensajeInicial(
          alumno, materia, resumen, AjustesService.instancia.nombreDocente));

  final enviar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mensaje por WhatsApp'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para: ${alumno.nombreCompleto}'),
            Text(Telefono.formatear(alumno.telefono),
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 12,
              minLines: 4,
              decoration: const InputDecoration(
                labelText: 'Revisá el mensaje antes de abrir WhatsApp',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir WhatsApp'),
        ),
      ],
    ),
  );

  // No se llama a ctrl.dispose() acá: el diálogo todavía puede estar
  // animando su cierre y usaría un controlador ya liberado.
  final texto = ctrl.text.trim();
  if (enviar != true || texto.isEmpty) return;

  try {
    await service.abrirChat(alumno.telefono, texto);
  } on ServicioException catch (e) {
    if (!context.mounted) return;
    mostrarMensaje(context, e.mensaje, error: true);
  }
}
