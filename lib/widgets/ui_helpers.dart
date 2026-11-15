import 'package:flutter/material.dart';

/// Muestra un mensaje breve en la parte inferior.
void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  final colores = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? colores.error : null,
    ));
}

/// Diálogo de confirmación Sí/No. Devuelve true si el usuario confirma.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Aceptar',
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}

/// Mensaje centrado para listas vacías.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;

  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: tema.colorScheme.outline),
            const SizedBox(height: 16),
            Text(titulo,
                style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(detalle,
                style: tema.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
