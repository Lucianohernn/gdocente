import 'package:flutter/material.dart';

import '../services/ajustes_service.dart';
import '../utils/app_tema.dart';
import 'carreras_screen.dart';

/// Se muestra solo la primera vez: pide el nombre para firmar los mensajes.
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final _nombreCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    await AjustesService.instancia.guardarNombre(_nombreCtrl.text);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const CarrerasScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const CircleAvatar(
              radius: 44,
              backgroundColor: Paleta.cobalto,
              child: Icon(Icons.school_outlined, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text('Bienvenido/a a GDocente',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Text(
              '¿Cómo querés firmar los mensajes de WhatsApp a tus alumnos?',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ej: Prof. María Gómez',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              onSubmitted: (_) => _continuar(),
            ),
            const SizedBox(height: 8),
            Text('Lo podés cambiar cuando quieras en Ajustes.',
                style: tema.textTheme.bodySmall),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _continuar,
                child: const Text('Comenzar', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _nombreCtrl.clear();
                _continuar();
              },
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}
