import 'package:dio/dio.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/router/app_routes.dart';
import 'package:frontend/shared/services/storage_service.dart';

class DioClient {
  DioClient._();

  static final Dio _dio = _createDio();

  static Dio get instance => _dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        // Android emulator  → http://10.0.2.2:8000
        // iOS simulator     → http://localhost:8000
        // Physical device   → http://YOUR_PC_IP:8000
        baseUrl: 'http://172.20.10.6:8000',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // ── Attach access token to every request ──
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },

        // ── Catch 401 and silently refresh ──
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;

          // Only handle 401 — pass everything else through
          if (statusCode != 401) {
            return handler.next(error);
          }

          // If the failing request IS /auth/refresh → refresh itself failed
          // Avoid infinite loop — force logout immediately
          final isRefreshCall = error.requestOptions.path.contains(
            '/auth/refresh',
          );

          if (isRefreshCall) {
            await _forceLogout();
            return handler.reject(error);
          }

          // Get the stored refresh token
          final refreshToken = await StorageService.getRefreshToken();

          if (refreshToken == null) {
            // Nothing stored → force logout
            await _forceLogout();
            return handler.reject(error);
          }

          try {
            // Use a clean Dio instance to call /auth/refresh
            // Not the main one — avoids triggering the interceptor again
            final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));

            final response = await refreshDio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );

            // Save the new access token
            final newAccessToken = response.data['access_token'];
            await StorageService.saveToken(newAccessToken);

            // Retry the original failed request with the new token
            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';

            final retryResponse = await dio.fetch(error.requestOptions);
            return handler.resolve(retryResponse);
          } catch (e) {
            // Refresh failed → force logout
            await _forceLogout();
            return handler.reject(error);
          }
        },
      ),
    );

    // Log all requests and responses
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );

    return dio;
  }

  /// Clears all tokens and redirects to Login.
  static Future<void> _forceLogout() async {
    await StorageService.clearAll();
    try {
      appRouter.go(AppRoutes.login);
    } catch (_) {}
    ;
  }
}
