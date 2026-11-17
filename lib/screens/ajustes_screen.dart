import 'package:flutter/material.dart';

import '../services/ajustes_service.dart';
import '../widgets/ui_helpers.dart';

/// Nombre del docente (firma de WhatsApp) y modo de color.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  final _ajustes = AjustesService.instancia;
  late final _nombreCtrl = TextEditingController(text: _ajustes.nombreDocente);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarNombre() async {
    FocusScope.of(context).unfocus();
    await _ajustes.guardarNombre(_nombreCtrl.text);
    if (!mounted) return;
    mostrarMensaje(context, 'Nombre guardado');
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tu nombre', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Se usa para firmar los mensajes de WhatsApp a tus alumnos.',
              style: tema.textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Prof. María Gómez',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onSubmitted: (_) => _guardarNombre(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _guardarNombre,
              icon: const Icon(Icons.save),
              label:
                  const Text('Guardar nombre', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 32),
          Text('Colores de la pantalla', style: tema.textTheme.titleLarge),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _ajustes,
            builder: (_, __) => RadioGroup<ThemeMode>(
              groupValue: _ajustes.modoTema,
              onChanged: (m) => _ajustes.guardarModoTema(m!),
              child: Column(
                children: [
                  for (final (modo, icono, texto, detalle) in const [
                    (
                      ThemeMode.system,
                      Icons.brightness_auto,
                      'Automático',
                      'Igual que el teléfono'
                    ),
                    (
                      ThemeMode.light,
                      Icons.light_mode,
                      'Modo claro',
                      'Fondo blanco'
                    ),
                    (
                      ThemeMode.dark,
                      Icons.dark_mode,
                      'Modo nocturno',
                      'Fondo oscuro, descansa la vista de noche'
                    ),
                  ])
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: RadioListTile<ThemeMode>(
                        value: modo,
                        secondary: Icon(icono),
                        title: Text(texto),
                        subtitle: Text(detalle),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
