import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del docente guardadas en el teléfono (sin login):
/// nombre para firmar los mensajes y modo de color (claro/oscuro).
/// Es un ChangeNotifier para que la app se repinte al cambiar el tema.
class AjustesService extends ChangeNotifier {
  AjustesService._();
  static final AjustesService instancia = AjustesService._();

  static const _kNombre = 'nombre_docente';
  static const _kTema = 'modo_tema';
  static const _kBienvenida = 'bienvenida_vista';

  SharedPreferences? _prefs;

  String _nombreDocente = '';
  ThemeMode _modoTema = ThemeMode.system;
  bool _bienvenidaVista = false;

  String get nombreDocente => _nombreDocente;
  ThemeMode get modoTema => _modoTema;
  bool get bienvenidaVista => _bienvenidaVista;

  Future<void> cargar() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    _nombreDocente = prefs.getString(_kNombre) ?? '';
    _bienvenidaVista = prefs.getBool(_kBienvenida) ?? false;
    _modoTema = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_kTema),
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> guardarNombre(String nombre) async {
    _nombreDocente = nombre.trim();
    _bienvenidaVista = true;
    await _prefs?.setString(_kNombre, _nombreDocente);
    await _prefs?.setBool(_kBienvenida, true);
    notifyListeners();
  }

  Future<void> guardarModoTema(ThemeMode modo) async {
    _modoTema = modo;
    await _prefs?.setString(_kTema, modo.name);
    notifyListeners();
  }
}
