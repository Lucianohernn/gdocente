import 'package:flutter/material.dart';

import '../models/alumno_model.dart';
import '../services/alumno_service.dart';
import '../services/servicio_exception.dart';
import '../utils/telefono.dart';
import '../widgets/ui_helpers.dart';

/// Alta y edición de alumno. La pantalla no conoce SQL: solo usa el servicio.
class AlumnoFormScreen extends StatefulWidget {
  final int materiaId;
  final AlumnoModel? alumno; // null = alta

  const AlumnoFormScreen({super.key, required this.materiaId, this.alumno});

  @override
  State<AlumnoFormScreen> createState() => _AlumnoFormScreenState();
}

class _AlumnoFormScreenState extends State<AlumnoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AlumnoService();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.alumno?.nombreCompleto ?? '');
  late final TextEditingController _telefonoCtrl = TextEditingController(
      text: widget.alumno == null
          ? ''
          : Telefono.paraEditar(widget.alumno!.telefono));
  bool _guardando = false;

  bool get _esEdicion => widget.alumno != null;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return; // corta si no es válido
    setState(() => _guardando = true);

    final alumno = AlumnoModel(
      id: widget.alumno?.id,
      materiaId: widget.materiaId,
      nombreCompleto: _nombreCtrl.text,
      telefono: _telefonoCtrl.text,
      fechaAlta: widget.alumno?.fechaAlta ?? DateTime.now().toIso8601String(),
      activo: widget.alumno?.activo ?? 1,
    );

    try {
      await _service.guardar(alumno);
      // Corrección respecto del tutorial (5.2): después de un await hay que
      // verificar que la pantalla siga montada antes de usar el context.
      if (!mounted) return;
      Navigator.pop(context, true); // vuelve a la lista indicando cambios
    } on ServicioException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar alumno' : 'Nuevo alumno')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombreCtrl,
              autofocus: !_esEdicion,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Ingresá el nombre completo'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Teléfono (WhatsApp)',
                prefixIcon: Icon(Icons.phone_outlined),
                prefixText: '+54 9 ',
                helperText: Telefono.ayuda,
              ),
              validator: Telefono.validar,
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
