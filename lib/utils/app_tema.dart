import 'package:flutter/material.dart';

/// Paleta 60/30/10 de GDocente:
/// 60% marfil (fondos) · 30% cobalto (barra, íconos, barras de asistencia)
/// · 10% rosa (lo que hay que mirar: alumnos en riesgo y acción principal).
class Paleta {
  // Modo claro
  static const marfil = Color(0xFFF3F0E8);
  static const cobalto = Color(0xFF2F4FBF);
  static const cobaltoSuave = Color(0xFFE7E9F3);
  static const rosa = Color(0xFFFF4FA3);
  static const rosaTexto = Color(0xFFC2186E); // rosa legible sobre fondo claro
  static const rosaSuave = Color(0xFFFFE3F0);
  static const tinta = Color(0xFF14182B);
  static const tintaSecundaria = Color(0xFF5B6072);

  /// Texto sobre el rosa: oscuro, porque el blanco no se lee bien encima.
  static const sobreRosa = Color(0xFF3A0820);

  // Modo nocturno (vidrio liviano: paneles translúcidos sobre azul noche)
  static const noche = Color(0xFF0A0F24);
  static const nocheBarra = Color(0xFF16204A);
  static const cobaltoClaro = Color(0xFF7F9BFF);
  static const rosaClaro = Color(0xFFFF7DBB);
  static const textoNoche = Color(0xFFEEF0F7);
  static const textoNocheSecundario = Color(0xFFA3ABC8);
}

/// Colores con significado que la pantalla pide según el modo.
/// Se leen con `ColoresApp.of(context)`.
@immutable
class ColoresApp extends ThemeExtension<ColoresApp> {
  final Color marca; // íconos y barras de asistencia
  final Color marcaSuave; // fondo de iniciales y pista de las barras
  final Color riesgo; // texto/barras de alumnos en riesgo
  final Color riesgoSuave;
  final Color textoSecundario;
  final Color panel; // fondo de paneles y botones
  final Color borde; // línea fina de paneles
  final Color brillo; // reflejo superior del vidrio (transparente en claro)
  final Color marcaRegla; // rayita del mínimo de asistencia

  const ColoresApp({
    required this.marca,
    required this.marcaSuave,
    required this.riesgo,
    required this.riesgoSuave,
    required this.textoSecundario,
    required this.panel,
    required this.borde,
    required this.brillo,
    required this.marcaRegla,
  });

  static ColoresApp of(BuildContext context) =>
      Theme.of(context).extension<ColoresApp>()!;

  static const claro = ColoresApp(
    marca: Paleta.cobalto,
    marcaSuave: Paleta.cobaltoSuave,
    riesgo: Paleta.rosaTexto,
    riesgoSuave: Paleta.rosaSuave,
    textoSecundario: Paleta.tintaSecundaria,
    panel: Colors.white,
    borde: Color(0x1F14182B), // tinta al 12%
    brillo: Colors.transparent,
    marcaRegla: Paleta.tinta,
  );

  static const oscuro = ColoresApp(
    marca: Paleta.cobaltoClaro,
    marcaSuave: Color(0x2E7F9BFF),
    riesgo: Paleta.rosaClaro,
    riesgoSuave: Color(0x2EFF4FA3),
    textoSecundario: Paleta.textoNocheSecundario,
    panel: Color(0x0DFFFFFF), // blanco al 5%: panel de vidrio
    borde: Color(0x24FFFFFF), // blanco al 14%
    brillo: Color(0x17FFFFFF), // blanco al 9%: reflejo arriba del panel
    marcaRegla: Paleta.textoNoche,
  );

  /// Decoración de panel: blanco con borde en claro, vidrio en nocturno.
  /// En nocturno el panel es un poco más claro arriba (reflejo del vidrio).
  BoxDecoration panelDecoracion(double radio) => BoxDecoration(
        color: brillo == Colors.transparent ? panel : null,
        gradient: brillo == Colors.transparent
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [brillo, panel],
                stops: const [0, 0.35],
              ),
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: borde, width: 0.8),
      );

  @override
  ColoresApp copyWith() => this;

  @override
  ColoresApp lerp(ColoresApp? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

class AppTema {
  static ThemeData claro() => _base(
        ColorScheme.fromSeed(
          seedColor: Paleta.cobalto,
          primary: Paleta.cobalto,
          onPrimary: Colors.white,
          secondary: Paleta.rosa,
          onSecondary: Paleta.sobreRosa,
          surface: Paleta.marfil,
          onSurface: Paleta.tinta,
          onSurfaceVariant: Paleta.tintaSecundaria,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF8F6F1),
          surfaceContainer: const Color(0xFFEFEBE2),
          surfaceContainerHigh: const Color(0xFFE9E5DB),
          surfaceContainerHighest: const Color(0xFFE3DED3),
        ),
        ColoresApp.claro,
        Paleta.cobalto,
      );

  static ThemeData oscuro() => _base(
        ColorScheme.fromSeed(
          seedColor: Paleta.cobalto,
          brightness: Brightness.dark,
          primary: Paleta.cobaltoClaro,
          onPrimary: Paleta.noche,
          secondary: Paleta.rosa,
          onSecondary: Paleta.sobreRosa,
          surface: Paleta.noche,
          onSurface: Paleta.textoNoche,
          onSurfaceVariant: Paleta.textoNocheSecundario,
          surfaceContainerLowest: const Color(0xFF070B1B),
          surfaceContainerLow: const Color(0xFF111833),
          surfaceContainer: const Color(0xFF151D3B),
          surfaceContainerHigh: const Color(0xFF1B2446),
          surfaceContainerHighest: const Color(0xFF222C52),
        ),
        ColoresApp.oscuro,
        Paleta.nocheBarra,
      );

  static ThemeData _base(ColorScheme colores, ColoresApp app, Color barra) {
    final base = ThemeData(colorScheme: colores, useMaterial3: true);
    const numeros = [FontFeature.tabularFigures()];
    return base.copyWith(
      extensions: [app],
      scaffoldBackgroundColor: colores.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: barra,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        shape: colores.brightness == Brightness.dark
            ? Border(bottom: BorderSide(color: app.borde, width: 0.8))
            : null,
      ),
      // Acción principal (+ Alumno, Guardar) en rosa con letra oscura.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Paleta.rosa,
        foregroundColor: Paleta.sobreRosa,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        extendedTextStyle: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, fontFeatures: numeros),
      ),
      cardTheme: CardThemeData(
        color: app.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: app.borde, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10))),
        enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(color: app.borde)),
      ),
      dividerTheme: DividerThemeData(color: app.borde, space: 1),
      // Letra un poco más grande que la estándar: más cómoda de leer.
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
        titleMedium: base.textTheme.titleMedium
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      dialogTheme: DialogThemeData(
        backgroundColor: colores.brightness == Brightness.dark
            ? const Color(0xFF151D3B)
            : Colors.white,
      ),
    );
  }
}
