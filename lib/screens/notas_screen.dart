import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alumno_model.dart';
import '../models/evaluacion_model.dart';
import '../models/materia_model.dart';
import '../models/nota_model.dart';
import '../services/alumno_service.dart';
import '../services/evaluacion_service.dart';
import '../services/resumen_academico.dart';
import '../services/servicio_exception.dart';
import '../utils/formato.dart';
import '../widgets/ui_helpers.dart';

/// Planilla de notas de una evaluación: nota original y recuperatorio.
class NotasScreen extends StatefulWidget {
  final MateriaModel materia;
  final EvaluacionModel evaluacion;

  const NotasScreen(
      {super.key, required this.materia, required this.evaluacion});

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> {
  final _service = EvaluacionService();
  final _alumnoService = AlumnoService();
  final _formKey = GlobalKey<FormState>();

  List<AlumnoModel> _alumnos = [];
  final Map<int, TextEditingController> _notaCtrl = {};
  final Map<int, TextEditingController> _recupCtrl = {};
  bool _cargando = true;
  bool _guardando = false;
  bool _cambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [..._notaCtrl.values, ..._recupCtrl.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final alumnos = await _alumnoService.listarActivos(widget.materia.id!);
    final notas = await _service.notasDe(widget.evaluacion);
    if (!mounted) return;
    String texto(double? n) => n == null ? '' : Formato.nota(n);
    setState(() {
      _alumnos = alumnos;
      for (final a in alumnos) {
        final n = notas[a.id];
        _notaCtrl[a.id!] = TextEditingController(text: texto(n?.nota));
        _recupCtrl[a.id!] =
            TextEditingController(text: texto(n?.recuperatorio));
      }
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      mostrarMensaje(context, 'Revisá las notas marcadas en rojo', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await _service.guardarNotas([
        for (final a in _alumnos)
          NotaModel(
            evaluacionId: widget.evaluacion.id!,
            alumnoId: a.id!,
            nota: Formato.leerNota(_notaCtrl[a.id]!.text),
            recuperatorio: Formato.leerNota(_recupCtrl[a.id]!.text),
          ),
      ]);
      if (!mounted) return;
      setState(() => _cambios = false);
      mostrarMensaje(context, 'Notas guardadas');
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _validar(String? v) {
    final n = Formato.leerNota(v ?? '');
    return EvaluacionService.notaValida(n) ? null : '1 a 10';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cambios,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final descartar = await confirmar(
          context,
          titulo: 'Cambios sin guardar',
          mensaje: 'Hay notas sin guardar. ¿Descartarlas?',
          textoConfirmar: 'Descartar',
        );
        if (descartar && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: TituloSeccion(
              icono: Icons.assignment, texto: widget.evaluacion.nombre),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${widget.materia.nombre} · ${Formato.fecha(widget.evaluacion.fecha)}'
                ' · Aprueba con ${Formato.nota(ResumenAcademico.notaAprobacion)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ),
        floatingActionButton: _alumnos.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _guardando || !_cambios ? null : _guardar,
                backgroundColor: _cambios
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: _cambios
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.save),
                label: Text(_cambios ? 'Guardar' : 'Guardado'),
              ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _alumnos.isEmpty
                ? const EstadoVacio(
                    icono: Icons.groups_outlined,
                    titulo: 'Sin alumnos',
                    detalle: 'Primero agregá los alumnos de la materia.',
                  )
                : Form(
                    key: _formKey,
                    onChanged: () {
                      if (!_cambios) setState(() => _cambios = true);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _alumnos.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i == 0) return _encabezado(context);
                        final a = _alumnos[i - 1];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(a.nombreCompleto,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              _CampoNota(
                                  controller: _notaCtrl[a.id]!,
                                  validator: _validar),
                              const SizedBox(width: 8),
                              _CampoNota(
                                  controller: _recupCtrl[a.id]!,
                                  validator: _validar),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _encabezado(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelMedium;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
      child: Row(
        children: [
          Expanded(child: Text('Alumno', style: estilo)),
          SizedBox(
              width: 72,
              child: Text('Nota', style: estilo, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          SizedBox(
              width: 72,
              child:
                  Text('Recup.', style: estilo, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _CampoNota extends StatelessWidget {
  final TextEditingController controller;
  final FormFieldValidator<String> validator;

  const _CampoNota({required this.controller, required this.validator});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          LengthLimitingTextInputFormatter(5),
        ],
        decoration: const InputDecoration(
          isDense: true,
          hintText: '–',
          errorMaxLines: 1,
        ),
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
    );
  }
}
