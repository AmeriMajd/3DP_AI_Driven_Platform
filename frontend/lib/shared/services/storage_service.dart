import 'package:shared_preferences/shared_preferences.dart';

/// Service de stockage local pour le token JWT.
/// Persiste le token entre les sessions.
class StorageService {
  StorageService._();

  static const String _tokenKey = 'auth_token';

  /// Sauvegarde le token JWT après login/signup
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Récupère le token stocké
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Supprime le token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static const String _refreshTokenKey = 'refresh_token';

static Future<void> saveRefreshToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_refreshTokenKey, token);
}

static Future<String?> getRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_refreshTokenKey);
}

static Future<void> clearRefreshToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_refreshTokenKey);
}
}