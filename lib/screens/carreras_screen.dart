import 'package:flutter/material.dart';

import '../models/carrera_model.dart';
import '../services/carrera_service.dart';
import '../services/servicio_exception.dart';
import '../widgets/ui_helpers.dart';
import 'materias_screen.dart';

/// Pantalla inicial: Carrera → Año/Materia → Alumnos.
class CarrerasScreen extends StatefulWidget {
  const CarrerasScreen({super.key});

  @override
  State<CarrerasScreen> createState() => _CarrerasScreenState();
}

class _CarrerasScreenState extends State<CarrerasScreen> {
  final _service = CarreraService();
  List<CarreraModel> _carreras = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final datos = await _service.listar();
    if (!mounted) return;
    setState(() {
      _carreras = datos;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([CarreraModel? carrera]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _CarreraDialog(carrera: carrera, service: _service),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _eliminar(CarreraModel carrera) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar carrera',
      mensaje: '¿Eliminar "${carrera.nombre}"?',
      textoConfirmar: 'Eliminar',
    );
    if (!ok) return;
    try {
      await _service.eliminar(carrera);
      await _cargar();
      if (!mounted) return;
      mostrarMensaje(context, 'Carrera eliminada');
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _abrirMaterias(CarreraModel carrera) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MateriasScreen(carrera: carrera)),
    );
    await _cargar(); // refresca contadores al volver
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GDocente · Carreras')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Carrera'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _carreras.isEmpty
              ? const EstadoVacio(
                  icono: Icons.school_outlined,
                  titulo: 'Todavía no hay carreras',
                  detalle: 'Tocá "+ Carrera" para crear la primera.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _carreras.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _carreras[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.school)),
                      title: Text(c.nombre),
                      subtitle: Text(c.cantidadMaterias == 1
                          ? '1 materia'
                          : '${c.cantidadMaterias} materias'),
                      onTap: () => _abrirMaterias(c),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) =>
                            op == 'editar' ? _abrirFormulario(c) : _eliminar(c),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'editar', child: Text('Editar')),
                          PopupMenuItem(
                              value: 'eliminar', child: Text('Eliminar')),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _CarreraDialog extends StatefulWidget {
  final CarreraModel? carrera;
  final CarreraService service;

  const _CarreraDialog({this.carrera, required this.service});

  @override
  State<_CarreraDialog> createState() => _CarreraDialogState();
}

class _CarreraDialogState extends State<_CarreraDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.carrera?.nombre ?? '');
  String? _errorServicio;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _errorServicio = null;
    });
    try {
      final base = widget.carrera ?? const CarreraModel(nombre: '');
      await widget.service.guardar(base.copyWith(nombre: _nombreCtrl.text));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ServicioException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorServicio = e.mensaje;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.carrera == null ? 'Nueva carrera' : 'Editar carrera'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nombreCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Desarrollo de software',
            errorText: _errorServicio,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          onFieldSubmitted: (_) => _guardar(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
