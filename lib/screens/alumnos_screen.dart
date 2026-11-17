import 'dart:io';

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
import '../utils/app_tema.dart';
import '../utils/formato.dart';
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
    final resumenes =
        await _resumenService.deMateria(widget.materia.id!, datos);
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
      if (Platform.isWindows) {
        // En la notebook no hay menú de compartir: ventana "Guardar como".
        final destino = await FilePicker.saveFile(
          dialogTitle: 'Guardar Excel',
          fileName: archivo.uri.pathSegments.last,
          bytes: await archivo.readAsBytes(),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (destino != null && mounted) {
          mostrarMensaje(context, 'Excel guardado');
        }
        return;
      }
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

  /// Aviso para el docente: "Asistencia baja", "Recupera Parcial 2"...
  /// null si el alumno está al día.
  static String? _aviso(ResumenAcademico? r) {
    if (r == null || !r.enRiesgo) return null;
    final recuperar = r.aRecuperar.map((n) => n.evaluacion).toList();
    return [
      if (r.asistenciaBaja) 'Asistencia baja',
      if (recuperar.length == 1) 'Recupera ${recuperar.first}',
      if (recuperar.length > 1) 'Recupera ${recuperar.length} evaluaciones',
    ].join(' · ');
  }

  List<AlumnoModel> get _filtrados {
    if (_filtro.isEmpty) return _alumnos;
    final f = _filtro.toLowerCase();
    return _alumnos
        .where((a) =>
            a.nombreCompleto.toLowerCase().contains(f) ||
            a.telefono.contains(f))
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
        alumno: alumno,
        materia: widget.materia,
        resumen: _resumenes[alumno.id]);
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    final app = ColoresApp.of(context);
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final enRiesgo =
        _alumnos.where((a) => _resumenes[a.id]?.enRiesgo ?? false).length;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.materia.anio}° año',
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            Text(widget.materia.nombre),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Excel',
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
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _buscarCtrl,
                onChanged: (v) => setState(() => _filtro = v.trim()),
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: oscuro ? app.panel : Paleta.marfil,
                  hintText: 'Buscar alumno',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _filtro.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Borrar búsqueda',
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Alumno'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accesos grandes y con nombre a las dos tareas más usadas.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: BotonSeccion(
                    icono: Icons.fact_check_outlined,
                    texto: 'Asistencia',
                    onTap: () =>
                        _abrir(AsistenciaScreen(materia: widget.materia)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BotonSeccion(
                    icono: Icons.assignment_outlined,
                    texto: 'Notas',
                    onTap: () =>
                        _abrir(EvaluacionesScreen(materia: widget.materia)),
                  ),
                ),
              ],
            ),
          ),
          if (!_cargando && _alumnos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: _alumnos.length == 1
                          ? '1 alumno'
                          : '${_alumnos.length} alumnos'),
                  if (enRiesgo > 0) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '$enRiesgo en riesgo',
                      style: TextStyle(
                          color: app.riesgo, fontWeight: FontWeight.w500),
                    ),
                  ],
                ]),
                style: TextStyle(fontSize: 14, color: app.textoSecundario),
              ),
            ),
          Expanded(child: _lista(lista)),
        ],
      ),
    );
  }

  Widget _lista(List<AlumnoModel> lista) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_alumnos.isEmpty) {
      return const EstadoVacio(
        icono: Icons.groups_outlined,
        titulo: 'Sin alumnos',
        detalle: 'Agregá los alumnos de esta materia con "+ Alumno".',
      );
    }
    if (lista.isEmpty) {
      return const EstadoVacio(
        icono: Icons.search_off,
        titulo: 'Sin resultados',
        detalle: 'No hay alumnos que coincidan con la búsqueda.',
      );
    }
    final app = ColoresApp.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        DecoratedBox(
          decoration: app.panelDecoracion(16),
          child: Column(
            children: [
              for (var i = 0; i < lista.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                FilaAlumno(
                  alumno: lista[i],
                  resumen: _resumenes[lista[i].id],
                  aviso: _aviso(_resumenes[lista[i].id]),
                  onTap: () => _abrirFormulario(lista[i]),
                  onWhatsApp: () => _whatsapp(lista[i]),
                  onBaja: () => _darDeBaja(lista[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila de alumno: nombre, barra de asistencia con la marca del mínimo,
/// porcentaje y promedio alineados, y aviso si necesita atención.
class FilaAlumno extends StatelessWidget {
  final AlumnoModel alumno;
  final ResumenAcademico? resumen;
  final String? aviso;
  final VoidCallback onTap;
  final VoidCallback onWhatsApp;
  final VoidCallback onBaja;

  const FilaAlumno({
    super.key,
    required this.alumno,
    required this.resumen,
    required this.aviso,
    required this.onTap,
    required this.onWhatsApp,
    required this.onBaja,
  });

  @override
  Widget build(BuildContext context) {
    final app = ColoresApp.of(context);
    final tema = Theme.of(context);
    final riesgo = aviso != null;
    final pct = resumen?.porcentajeAsistencia;
    final promedio = resumen?.promedio;
    const cifras = [FontFeature.tabularFigures()];

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: riesgo ? app.riesgoSuave : app.marcaSuave,
              child: Text(
                alumno.nombreCompleto[0].toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: riesgo ? app.riesgo : app.marca),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alumno.nombreCompleto,
                      style: tema.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (pct != null) ...[
                    const SizedBox(height: 8),
                    BarraAsistencia(
                        porcentaje: pct, baja: resumen!.asistenciaBaja),
                  ],
                  if (aviso != null) ...[
                    const SizedBox(height: 4),
                    Text(aviso!,
                        style: TextStyle(
                            fontSize: 13,
                            color: app.riesgo,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Ancho fijo: así las barras y la marca del mínimo quedan
            // alineadas en todas las filas.
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(pct == null ? '–' : Formato.porcentaje(pct),
                      style: tema.textTheme.bodyLarge
                          ?.copyWith(fontFeatures: cifras)),
                  Text(
                    promedio == null
                        ? 'Sin notas'
                        : 'Prom. ${Formato.nota(promedio)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: app.textoSecundario,
                        fontFeatures: cifras),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat),
              color: const Color(0xFF25D366),
              tooltip: 'Mensaje por WhatsApp',
              onPressed: onWhatsApp,
            ),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (_) => onBaja(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'baja',
                  child: ListTile(
                    leading: Icon(Icons.person_remove_outlined),
                    title: Text('Dar de baja'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
