import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/alumno_model.dart';
import '../models/materia_model.dart';
import '../services/alumno_service.dart';
import '../services/excel_service.dart';
import '../services/resumen_academico.dart';
import '../services/resumen_service.dart';
import '../services/servicio_exception.dart';
import '../utils/formato.dart';
import '../utils/telefono.dart';
import '../widgets/mensaje_whatsapp_dialog.dart';
import '../widgets/ui_helpers.dart';
import 'alumno_form_screen.dart';
import 'asistencia_screen.dart';
import 'evaluaciones_screen.dart';

class AlumnosScreen extends StatefulWidget {
  final MateriaModel materia;
  const AlumnosScreen({super.key, required this.materia});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  final _service = AlumnoService();
  final _resumenService = ResumenService();
  final _excelService = ExcelService();
  final _buscarCtrl = TextEditingController();
  List<AlumnoModel> _alumnos = [];
  Map<int, ResumenAcademico> _resumenes = {};
  String _filtro = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final datos = await _service.listarActivos(widget.materia.id!);
    final resumenes = await _resumenService.deMateria(widget.materia.id!, datos);
    if (!mounted) return;
    setState(() {
      _alumnos = datos;
      _resumenes = resumenes;
      _cargando = false;
    });
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    await _cargar(); // la asistencia y las notas cambian el resumen
  }

  Future<void> _exportarExcel() async {
    mostrarMensaje(context, 'Generando Excel...');
    try {
      final archivo = await _excelService.exportarMateria(widget.materia);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Abre el menú de Android para guardarlo (Drive, Archivos) o enviarlo.
      await SharePlus.instance.share(ShareParams(
        files: [XFile(archivo.path)],
        subject: 'GDocente - ${widget.materia.nombre}',
      ));
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _importarExcel() async {
    final ok = await confirmar(
      context,
      titulo: 'Importar desde Excel',
      mensaje: 'Podés elegir:\n\n'
          '• Un Excel exportado por GDocente: recupera alumnos, asistencias '
          'y notas (sirve para pasar los datos a otro celular).\n\n'
          '• Una lista simple: nombre completo en la columna A y teléfono en '
          'la columna B.\n\n'
          'Los alumnos que ya están se mantienen. Si una asistencia o nota ya '
          'existe, la del Excel la reemplaza.',
      textoConfirmar: 'Elegir archivo',
    );
    if (!ok) return;
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (archivo == null) return;
    try {
      final resultado = await _excelService.importarMateria(
          await archivo.readAsBytes(), widget.materia.id!);
      await _cargar();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importación terminada'),
          content: SingleChildScrollView(
            child: Text(resultado.detalle),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } on ServicioException catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  String _detalle(AlumnoModel a) {
    final r = _resumenes[a.id];
    final partes = [
      Telefono.formatear(a.telefono),
      if (r?.porcentajeAsistencia != null)
        'Asist. ${Formato.porcentaje(r!.porcentajeAsistencia!)}',
      if (r?.promedio != null) 'Prom. ${Formato.nota(r!.promedio!)}',
      if (r != null && r.aRecuperar.isNotEmpty)
        '${r.aRecuperar.length} a recuperar',
    ];
    return partes.join(' · ');
  }

  List<AlumnoModel> get _filtrados {
    if (_filtro.isEmpty) return _alumnos;
    final f = _filtro.toLowerCase();
    return _alumnos
        .where((a) =>
            a.nombreCompleto.toLowerCase().contains(f) || a.telefono.contains(f))
        .toList();
  }

  Future<void> _abrirFormulario([AlumnoModel? alumno]) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AlumnoFormScreen(materiaId: widget.materia.id!, alumno: alumno),
      ),
    );
    if (guardado == true) {
      await _cargar();
      if (!mounted) return;
      mostrarMensaje(
          context, alumno == null ? 'Alumno agregado' : 'Alumno actualizado');
    }
  }

  Future<void> _darDeBaja(AlumnoModel alumno) async {
    final ok = await confirmar(
      context,
      titulo: 'Dar de baja',
      mensaje: '¿Dar de baja a ${alumno.nombreCompleto} de esta materia?',
      textoConfirmar: 'Dar de baja',
    );
    if (!ok) return;
    await _service.darDeBaja(alumno);
    await _cargar();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${alumno.nombreCompleto} dado de baja'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            try {
              await _service.deshacerBaja(alumno);
            } on ServicioException catch (e) {
              if (mounted) mostrarMensaje(context, e.mensaje, error: true);
            }
            await _cargar();
          },
        ),
      ));
  }

  Future<void> _whatsapp(AlumnoModel alumno) async {
    await mostrarMensajeWhatsApp(context,
        alumno: alumno, materia: widget.materia, resumen: _resumenes[alumno.id]);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.materia.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: 'Asistencia',
            onPressed: () => _abrir(AsistenciaScreen(materia: widget.materia)),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'Evaluaciones y notas',
            onPressed: () =>
                _abrir(EvaluacionesScreen(materia: widget.materia)),
          ),
          PopupMenuButton<String>(
            onSelected: (op) =>
                op == 'exportar' ? _exportarExcel() : _importarExcel(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'exportar',
                child: ListTile(
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Exportar a Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'importar',
                child: ListTile(
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Importar desde Excel'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _buscarCtrl,
              onChanged: (v) => setState(() => _filtro = v.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar alumno',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _filtro.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscarCtrl.clear();
                          setState(() => _filtro = '');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Alumno'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _alumnos.isEmpty
              ? const EstadoVacio(
                  icono: Icons.groups_outlined,
                  titulo: 'Sin alumnos',
                  detalle: 'Agregá los alumnos de esta materia con "+ Alumno".',
                )
              : lista.isEmpty
                  ? const EstadoVacio(
                      icono: Icons.search_off,
                      titulo: 'Sin resultados',
                      detalle: 'No hay alumnos que coincidan con la búsqueda.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = lista[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(a.nombreCompleto[0].toUpperCase()),
                          ),
                          title: Text(a.nombreCompleto),
                          subtitle: Text(_detalle(a)),
                          onTap: () => _abrirFormulario(a),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat),
                                color: const Color(0xFF25D366),
                                tooltip: 'Mensaje por WhatsApp',
                                onPressed: () => _whatsapp(a),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: 'Dar de baja',
                                onPressed: () => _darDeBaja(a),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
