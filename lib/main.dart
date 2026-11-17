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
        home: ajustes.bienvenidaVista
            ? const CarrerasScreen()
            : const BienvenidaScreen(),
      ),
    );
  }
}
