import 'package:flutter/material.dart';

import '../models/evaluacion_model.dart';
import '../models/materia_model.dart';
import '../services/evaluacion_service.dart';
import '../services/servicio_exception.dart';
import '../utils/formato.dart';
import '../widgets/ui_helpers.dart';
import 'notas_screen.dart';

class EvaluacionesScreen extends StatefulWidget {
  final MateriaModel materia;
  const EvaluacionesScreen({super.key, required this.materia});

  @override
  State<EvaluacionesScreen> createState() => _EvaluacionesScreenState();
}

class _EvaluacionesScreenState extends State<EvaluacionesScreen> {
  final _service = EvaluacionService();
  List<EvaluacionModel> _evaluaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final datos = await _service.listarPorMateria(widget.materia.id!);
    if (!mounted) return;
    setState(() {
      _evaluaciones = datos;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([EvaluacionModel? evaluacion]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _EvaluacionDialog(
        materiaId: widget.materia.id!,
        evaluacion: evaluacion,
        service: _service,
      ),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _eliminar(EvaluacionModel e) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar evaluación',
      mensaje: e.cantidadNotas > 0
          ? '¿Eliminar "${e.nombre}" y sus ${e.cantidadNotas} nota(s) cargada(s)?'
          : '¿Eliminar "${e.nombre}"?',
      textoConfirmar: 'Eliminar',
    );
    if (!ok) return;
    await _service.eliminar(e);
    await _cargar();
    if (!mounted) return;
    mostrarMensaje(context, 'Evaluación eliminada');
  }

  Future<void> _abrirNotas(EvaluacionModel e) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotasScreen(materia: widget.materia, evaluacion: e),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Evaluaciones · ${widget.materia.nombre}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Evaluación'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _evaluaciones.isEmpty
              ? const EstadoVacio(
                  icono: Icons.assignment_outlined,
                  titulo: 'Sin evaluaciones',
                  detalle: 'Agregá parciales, trabajos prácticos u otras '
                      'instancias para cargar las notas.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _evaluaciones.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = _evaluaciones[i];
                    return ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.assignment_outlined)),
                      title: Text(e.nombre),
                      subtitle: Text('${Formato.fecha(e.fecha)} · '
                          '${e.cantidadNotas} nota(s) cargada(s)'),
                      onTap: () => _abrirNotas(e),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) =>
                            op == 'editar' ? _abrirFormulario(e) : _eliminar(e),
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

class _EvaluacionDialog extends StatefulWidget {
  final int materiaId;
  final EvaluacionModel? evaluacion;
  final EvaluacionService service;

  const _EvaluacionDialog({
    required this.materiaId,
    this.evaluacion,
    required this.service,
  });

  @override
  State<_EvaluacionDialog> createState() => _EvaluacionDialogState();
}

class _EvaluacionDialogState extends State<_EvaluacionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.evaluacion?.nombre ?? '');
  late DateTime _fecha = widget.evaluacion == null
      ? DateTime.now()
      : Formato.desdeIso(widget.evaluacion!.fecha);
  String? _errorServicio;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _errorServicio = null;
    });
    try {
      await widget.service.guardar(EvaluacionModel(
        id: widget.evaluacion?.id,
        materiaId: widget.materiaId,
        nombre: _nombreCtrl.text,
        fecha: Formato.fechaIso(_fecha),
      ));
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
      title: Text(widget.evaluacion == null
          ? 'Nueva evaluación'
          : 'Editar evaluación'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Parcial 1',
                errorText: _errorServicio,
                errorMaxLines: 2,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text('Fecha: ${Formato.fecha(Formato.fechaIso(_fecha))}'),
            ),
          ],
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
