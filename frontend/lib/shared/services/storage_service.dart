import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure local storage for JWT tokens.
/// Uses device keychain encryption — never plain text.
class StorageService {
  StorageService._();

  static const _storage = FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userRoleKey = 'user_role';
  static const String _fullNameKey = 'full_name';

  // ── Access Token ──
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _accessTokenKey);
  }

  // ── Refresh Token ──
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // ── User Role ──
  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  // ── User Name (Avatar) ──
  static Future<void> saveFullName(String name) async {
  await _storage.write(key: _fullNameKey, value: name);
  }

static Future<String?> getFullName() async {
  return await _storage.read(key: _fullNameKey);
}

  // ── Clear Everything (logout) ──
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static const String _userIdKey = 'user_id';

  static Future<void> saveUserId(String id) async {
    await _storage.write(key: _userIdKey, value: id);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }
}
