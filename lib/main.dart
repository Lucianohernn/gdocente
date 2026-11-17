import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/bienvenida_screen.dart';
import 'screens/carreras_screen.dart';
import 'services/ajustes_service.dart';
import 'utils/app_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AjustesService.instancia.cargar();
  runApp(const GDocenteApp());
}

class GDocenteApp extends StatelessWidget {
  const GDocenteApp({super.key});

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
