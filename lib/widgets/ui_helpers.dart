import 'package:flutter/material.dart';
import '../services/resumen_academico.dart';
import '../utils/app_tema.dart';

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

/// Botón grande con ícono y nombre (Asistencia, Notas...).
/// Fondo neutro: el color queda para los datos de los alumnos.
class BotonSeccion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const BotonSeccion({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final app = ColoresApp.of(context);
    return DecoratedBox(
      decoration: app.panelDecoracion(14),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(icono, color: app.marca, size: 22),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(texto,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de barra superior con el ícono de la sección.
class TituloSeccion extends StatelessWidget {
  final IconData icono;
  final String texto;

  const TituloSeccion({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, color: Colors.white70),
        const SizedBox(width: 12),
        Flexible(child: Text(texto, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

/// Barra de asistencia con una rayita en el mínimo de regularidad,
/// como la marca de una regla. En rosa si está por debajo.
class BarraAsistencia extends StatelessWidget {
  final double porcentaje;
  final bool baja;

  const BarraAsistencia(
      {super.key, required this.porcentaje, required this.baja});

  @override
  Widget build(BuildContext context) {
    final app = ColoresApp.of(context);
    final relleno = baja
        ? (Theme.of(context).brightness == Brightness.dark
            ? Paleta.rosa
            : Paleta.rosa)
        : app.marca;
    return Semantics(
      label: 'Asistencia ${porcentaje.round()} por ciento',
      child: SizedBox(
        height: 12,
        child: LayoutBuilder(
          builder: (_, c) {
            final ancho = c.maxWidth;
            final minimo = ancho * ResumenAcademico.asistenciaMinima / 100;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                      color: app.marcaSuave,
                      borderRadius: BorderRadius.circular(3)),
                ),
                Container(
                  height: 6,
                  width: ancho * (porcentaje.clamp(0, 100) / 100),
                  decoration: BoxDecoration(
                      color: relleno, borderRadius: BorderRadius.circular(3)),
                ),
                Positioned(
                  left: minimo - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                        color: app.marcaRegla,
                        borderRadius: BorderRadius.circular(1)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
