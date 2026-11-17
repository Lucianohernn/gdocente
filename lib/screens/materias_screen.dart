import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/carrera_model.dart';
import '../models/materia_model.dart';
import '../services/materia_service.dart';
import '../services/servicio_exception.dart';
import '../utils/app_tema.dart';
import '../widgets/ui_helpers.dart';
import 'alumnos_screen.dart';

class MateriasScreen extends StatefulWidget {
  final CarreraModel carrera;
  const MateriasScreen({super.key, required this.carrera});

  @override
  State<MateriasScreen> createState() => _MateriasScreenState();
}

class _MateriasScreenState extends State<MateriasScreen> {
  final _service = MateriaService();
  List<MateriaModel> _materias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final datos = await _service.listarPorCarrera(widget.carrera.id!);
    if (!mounted) return;
    setState(() {
      _materias = datos;
      _cargando = false;
    });
  }

  Future<void> _abrirFormulario([MateriaModel? materia]) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _MateriaDialog(
        carreraId: widget.carrera.id!,
        materia: materia,
        service: _service,
      ),
    );
    if (guardado == true) await _cargar();
  }

  Future<void> _eliminar(MateriaModel materia) async {
    final ok = await confirmar(
      context,
      titulo: 'Eliminar materia',
      mensaje: '¿Eliminar "${materia.nombre}"?',
      textoConfirmar: 'Eliminar',
    );
    if (!ok) return;
    try {
      await _service.eliminar(materia);
      await _cargar();
      if (!mounted) return;
      mostrarMensaje(context, 'Materia eliminada');
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _abrirAlumnos(MateriaModel materia) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlumnosScreen(materia: materia)),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.carrera.nombre)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Materia'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _materias.isEmpty
              ? const EstadoVacio(
                  icono: Icons.menu_book_outlined,
                  titulo: 'Sin materias',
                  detalle: 'Agregá las materias que dictás en esta carrera.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _materias.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = _materias[i];
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: ColoresApp.of(context).marcaSuave,
                          foregroundColor: ColoresApp.of(context).marca,
                          child: Text('${m.anio}°')),
                      title: Text(m.nombre),
                      subtitle: Text(
                          '${m.anio}° año · ${m.cantidadAlumnos} alumno(s)'),
                      onTap: () => _abrirAlumnos(m),
                      trailing: PopupMenuButton<String>(
                        onSelected: (op) =>
                            op == 'editar' ? _abrirFormulario(m) : _eliminar(m),
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

class _MateriaDialog extends StatefulWidget {
  final int carreraId;
  final MateriaModel? materia;
  final MateriaService service;

  const _MateriaDialog({
    required this.carreraId,
    this.materia,
    required this.service,
  });

  @override
  State<_MateriaDialog> createState() => _MateriaDialogState();
}

class _MateriaDialogState extends State<_MateriaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl =
      TextEditingController(text: widget.materia?.nombre ?? '');
  late final TextEditingController _anioCtrl =
      TextEditingController(text: widget.materia?.anio.toString() ?? '');
  String? _errorServicio;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _anioCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _errorServicio = null;
    });
    try {
      final datos = MateriaModel(
        id: widget.materia?.id,
        carreraId: widget.carreraId,
        nombre: _nombreCtrl.text,
        anio: int.parse(_anioCtrl.text),
      );
      await widget.service.guardar(datos);
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
      title: Text(widget.materia == null ? 'Nueva materia' : 'Editar materia'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Laboratorio II',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _anioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Año / nivel',
                hintText: 'Ej: 3',
                errorText: _errorServicio,
                errorMaxLines: 2,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null) return 'Ingresá un número';
                if (n < 1 || n > 9) return 'Entre 1 y 9';
                return null;
              },
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
