import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bienvenida_screen.dart';
import 'screens/carreras_screen.dart';
import 'services/ajustes_service.dart';
import 'services/backup_service.dart';
import 'utils/app_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AjustesService.instancia.cargar();
  await BackupService.instancia.cargar();
  runApp(const GDocenteApp());
}

class GDocenteApp extends StatefulWidget {
  const GDocenteApp({super.key});

  @override
  State<GDocenteApp> createState() => _GDocenteAppState();
}

/// Backup automático a Google Drive, una vez por día: al abrir la app, al
/// volver a ella y, en Windows, al cerrar la ventana (espera a que termine).
class _GDocenteAppState extends State<GDocenteApp> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onResume: BackupService.instancia.automaticoSiCorresponde,
      onExitRequested: () async {
        await BackupService.instancia
            .automaticoSiCorresponde()
            .timeout(const Duration(seconds: 20), onTimeout: () {});
        return AppExitResponse.exit;
      },
    );
    // Se deja arrancar la app primero; el backup va después, sin apuro.
    Future.delayed(const Duration(seconds: 5),
        BackupService.instancia.automaticoSiCorresponde);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = AjustesService.instancia;
    // Se repinta cuando el docente cambia el modo claro/oscuro.
    return ListenableBuilder(
      listenable: ajustes,
      builder: (_, __) => MaterialApp(
        title: 'GDocente',
        debugShowCheckedModeBanner: false,
        theme: AppTema.claro(),
        darkTheme: AppTema.oscuro(),
        themeMode: ajustes.modoTema,
        // Calendarios, botones y textos del sistema en español.
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // En la notebook la ventana es ancha: el contenido se limita a una
        // columna cómoda de leer en lugar de estirarse de borde a borde.
        builder: (context, child) => _ColumnaCentral(child: child!),
        home: ajustes.bienvenidaVista
            ? const CarrerasScreen()
            : const BienvenidaScreen(),
      ),
    );
  }
}

class _ColumnaCentral extends StatelessWidget {
  final Widget child;
  const _ColumnaCentral({required this.child});

  static const _anchoMaximo = 900.0;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    if (ancho <= _anchoMaximo) return child; // celular: sin cambios
    final app = ColoresApp.of(context);
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerLowest
          : Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: Container(
          width: _anchoMaximo,
          decoration: BoxDecoration(
            border: Border.symmetric(
                vertical: BorderSide(color: app.borde, width: 0.8)),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                size: Size(_anchoMaximo, MediaQuery.sizeOf(context).height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
