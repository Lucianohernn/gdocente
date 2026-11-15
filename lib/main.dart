import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/carreras_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GDocenteApp());
}

class GDocenteApp extends StatelessWidget {
  const GDocenteApp({super.key});

  static const Color colorPrincipal = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GDocente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: colorPrincipal),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // Calendarios, botones y textos del sistema en español.
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const CarrerasScreen(),
    );
  }
}
