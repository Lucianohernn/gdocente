import 'package:flutter/material.dart';

import '../models/alumno_model.dart';
import '../models/asistencia_model.dart';
import '../models/materia_model.dart';
import '../services/alumno_service.dart';
import '../services/asistencia_service.dart';
import '../services/resumen_academico.dart';
import '../services/resumen_service.dart';
import '../services/servicio_exception.dart';
import '../utils/formato.dart';
import '../widgets/ui_helpers.dart';

/// Planilla de asistencia de una materia para un día.
class AsistenciaScreen extends StatefulWidget {
  final MateriaModel materia;
  const AsistenciaScreen({super.key, required this.materia});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  final _service = AsistenciaService();
  final _alumnoService = AlumnoService();
  final _resumenService = ResumenService();

  DateTime _dia = _hoy();
  List<AlumnoModel> _alumnos = [];
  Map<int, EstadoAsistencia?> _estados = {};
  Map<int, ResumenAcademico> _resumenes = {};
  bool _cargando = true;
  bool _guardando = false;
  bool _cambios = false; // hay marcas sin guardar

  static DateTime _hoy() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  int get _materiaId => widget.materia.id!;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final alumnos = await _alumnoService.listarActivos(_materiaId);
    final guardados = await _service.estadosDelDia(_materiaId, _dia);
    final resumenes = await _resumenService.deMateria(_materiaId, alumnos);
    if (!mounted) return;
    setState(() {
      _alumnos = alumnos;
      _estados = {for (final a in alumnos) a.id!: guardados[a.id]};
      _resumenes = resumenes;
      _cambios = false;
      _cargando = false;
    });
  }

  /// Antes de cambiar de día o salir, avisa si hay marcas sin guardar.
  Future<bool> _puedeDescartar() async {
    if (!_cambios) return true;
    return confirmar(
      context,
      titulo: 'Cambios sin guardar',
      mensaje: 'La asistencia de este día tiene cambios sin guardar. '
          '¿Descartarlos?',
      textoConfirmar: 'Descartar',
    );
  }

  Future<void> _irADia(DateTime dia) async {
    if (dia == _dia || !await _puedeDescartar()) return;
    _dia = dia;
    await _cargar();
  }

  Future<void> _elegirFecha() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2020),
      lastDate: _hoy(),
      helpText: 'Fecha de la clase',
    );
    if (elegido != null) await _irADia(elegido);
  }

  Future<void> _verClasesAnteriores() async {
    final fechas = await _service.fechasConRegistro(_materiaId);
    if (!mounted) return;
    if (fechas.isEmpty) {
      mostrarMensaje(context, 'Todavía no hay clases registradas');
      return;
    }
    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Clases registradas')),
            for (final f in fechas)
              ListTile(
                leading: const Icon(Icons.event_available),
                title: Text(Formato.fecha(f)),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (elegida != null) await _irADia(Formato.desdeIso(elegida));
  }

  void _marcar(int alumnoId, EstadoAsistencia? estado) {
    setState(() {
      _estados[alumnoId] = estado;
      _cambios = true;
    });
  }

  void _todosPresentes() {
    setState(() {
      for (final a in _alumnos) {
        _estados[a.id!] ??= EstadoAsistencia.presente;
      }
      _cambios = true;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _service.guardarDia(_dia, _estados);
      await _cargar();
      if (!mounted) return;
      mostrarMensaje(context, 'Asistencia del ${Formato.fecha(Formato.fechaIso(_dia))} guardada');
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrarDia() async {
    final ok = await confirmar(
      context,
      titulo: 'Borrar clase',
      mensaje: '¿Borrar toda la asistencia del '
          '${Formato.fecha(Formato.fechaIso(_dia))}?',
      textoConfirmar: 'Borrar',
    );
    if (!ok) return;
    await _service.eliminarDia(_materiaId, _dia);
    await _cargar();
    if (!mounted) return;
    mostrarMensaje(context, 'Clase borrada');
  }

  String get _conteo {
    final c = <EstadoAsistencia, int>{};
    var sinMarcar = 0;
    for (final e in _estados.values) {
      if (e == null) {
        sinMarcar++;
      } else {
        c[e] = (c[e] ?? 0) + 1;
      }
    }
    final partes = [
      for (final e in EstadoAsistencia.values)
        if ((c[e] ?? 0) > 0) '${c[e]} ${e.etiqueta.toLowerCase()}',
      if (sinMarcar > 0) '$sinMarcar sin marcar',
    ];
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final esHoy = _dia == _hoy();
    return PopScope(
      canPop: !_cambios,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _puedeDescartar() && context.mounted) {
          setState(() => _cambios = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Asistencia'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Clases anteriores',
              onPressed: _verClasesAnteriores,
            ),
            PopupMenuButton<String>(
              onSelected: (op) => op == 'borrar' ? _borrarDia() : null,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'borrar', child: Text('Borrar esta clase')),
              ],
            ),
          ],
        ),
        floatingActionButton: _alumnos.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _guardando || !_cambios ? null : _guardar,
                backgroundColor: _cambios
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                icon: _guardando
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_cambios ? 'Guardar' : 'Guardado'),
              ),
        body: Column(
          children: [
            // Selector de fecha
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Día anterior',
                      onPressed: () =>
                          _irADia(_dia.subtract(const Duration(days: 1))),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _elegirFecha,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          '${esHoy ? 'Hoy, ' : ''}${Formato.fecha(Formato.fechaIso(_dia))}',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Día siguiente',
                      onPressed: esHoy
                          ? null
                          : () => _irADia(_dia.add(const Duration(days: 1))),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _cuerpo()),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_alumnos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.groups_outlined,
        titulo: 'Sin alumnos',
        detalle: 'Primero agregá los alumnos de la materia.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(_conteo,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextButton.icon(
                onPressed: _todosPresentes,
                icon: const Icon(Icons.done_all),
                label: const Text('Resto presentes'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: _alumnos.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = _alumnos[i];
              final pct = _resumenes[a.id]?.porcentajeAsistencia;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.nombreCompleto,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(
                            pct == null
                                ? 'Sin clases registradas'
                                : 'Asistencia: ${Formato.porcentaje(pct)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _SelectorEstado(
                      estado: _estados[a.id],
                      onChanged: (e) => _marcar(a.id!, e),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// P / A / T / J. Tocar el estado ya marcado lo desmarca.
class _SelectorEstado extends StatelessWidget {
  final EstadoAsistencia? estado;
  final ValueChanged<EstadoAsistencia?> onChanged;

  const _SelectorEstado({required this.estado, required this.onChanged});

  static Color _color(EstadoAsistencia e, ColorScheme c) => switch (e) {
        EstadoAsistencia.presente => const Color(0xFF2E7D32),
        EstadoAsistencia.ausente => c.error,
        EstadoAsistencia.tarde => const Color(0xFFEF6C00),
        EstadoAsistencia.justificada => const Color(0xFF1565C0),
      };

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in EstadoAsistencia.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: e.etiqueta,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(estado == e ? null : e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: estado == e ? _color(e, colores) : null,
                    border: Border.all(
                      color: estado == e ? _color(e, colores) : colores.outlineVariant,
                    ),
                  ),
                  child: Text(
                    e.codigo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: estado == e ? Colors.white : colores.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
