import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const String _kUserKey = 'current_user';
  static const String _kTokenKey = 'auth_token';

  static Map<String, dynamic>? _user;
  static String? _token;

  static Map<String, dynamic>? get user => _user;
  static String? get token => _token;

  // =========================
  // Guardar usuario + token
  // =========================
  static Future<void> setSession({
    required Map<String, dynamic> user,
    required String token,
  }) async {
    _user = user;
    _token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(user));
    await prefs.setString(_kTokenKey, token);
  }

  // =========================
  // Cargar desde SharedPreferences
  // =========================
  static Future<Map<String, dynamic>?> loadUser() async {
    if (_user != null) return _user;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null) return null;

    _user = jsonDecode(raw) as Map<String, dynamic>;
    return _user;
  }

  static Future<String?> loadToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
    return _token;
  }

  static Future<void> loadSession() async {
    await loadUser();
    await loadToken();
  }

  // =========================
  // Limpiar sesión
  // =========================
  static Future<void> clear() async {
    _user = null;
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    await prefs.remove(_kTokenKey);
  }

  // =========================
  // Helpers de lectura
  // =========================
  static String getNombre() => (_user?['nombre'] ?? 'Sin nombre').toString();
  static String getCorreo() => (_user?['correo'] ?? 'Sin correo').toString();

  // =========================
  // ✅ Helpers de actualización
  // =========================
  static Future<void> updateNombre(String nuevoNombre) async {
    await _updateUserField('nombre', nuevoNombre.trim());
  }

  // ✅ IMPORTANTÍSIMO: debe ser avatar_b64 (como lo usa Flutter en Perfil/Navbar/EditarPerfil)
  static Future<void> updateAvatarB64(String? avatarB64) async {
    await _updateUserField('avatar_b64', avatarB64);
  }

  static Future<void> _updateUserField(String key, dynamic value) async {
    if (_user == null) {
      await loadUser();
    }
    if (_user == null) return;

    _user = Map<String, dynamic>.from(_user!);
    _user![key] = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(_user));
  }
}
