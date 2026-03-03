import 'package:dio/dio.dart';
import '../services/storage_service.dart';

/// Client HTTP centralisé pour toutes les requêtes vers le backend.
/// 
/// Configuré avec :
/// - baseUrl pointant vers le serveur FastAPI
/// - timeout de 30 secondes
/// - logs en mode debug
/// 
/// Usage : injecté via [authRepositoryProvider] dans auth_provider.dart
class DioClient {
  DioClient._();

  static Dio get instance {
    final dio = Dio(
      BaseOptions(
        // ⚠️ Remplace par l'IP de ton partenaire en local
        // Ex: 'http://192.168.1.10:8000'
        // En production : 'https://api.3dp-platform.com'
        baseUrl: 'http://localhost:8000',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // ── Interceptor — ajoute le token JWT automatiquement ──
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    // Log chaque requête/réponse en mode debug
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    return dio;
  }
}