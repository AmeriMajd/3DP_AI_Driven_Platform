import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/router/app_routes.dart';
import 'package:frontend/shared/services/storage_service.dart';

class DioClient {
  DioClient._();

  static final List<String> _baseUrlCandidates = _resolveBaseUrlCandidates();
  static int _activeBaseUrlIndex = 0;

  static final Dio _dio = _createDio();

  static Dio get instance => _dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrlCandidates.first,
        connectTimeout: const Duration(seconds: 5),
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
          options.baseUrl = _baseUrlCandidates[_activeBaseUrlIndex];

          final token = await StorageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },

        // ── Catch 401 and silently refresh ──
        onError: (error, handler) async {
          if (_isConnectivityError(error) && !_alreadyRetriedBaseUrl(error)) {
            final nextBaseUrl = _nextBaseUrl();
            if (nextBaseUrl != null) {
              try {
                final retryOptions = error.requestOptions.copyWith(
                  baseUrl: nextBaseUrl,
                  extra: {
                    ...error.requestOptions.extra,
                    '_base_url_retry': true,
                  },
                );

                final retryResponse = await dio.fetch(retryOptions);
                dio.options.baseUrl = nextBaseUrl;
                return handler.resolve(retryResponse);
              } catch (_) {
                // Let normal error handling continue.
              }
            }
          }

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

  static List<String> _resolveBaseUrlCandidates() {
    final target = _readEnv('API_TARGET')?.toLowerCase() ?? 'auto';

    if (kIsWeb) {
      return _uniqueNonEmpty([
        if (target == 'localhost') _readEnv('API_BASE_URL'),
        _readEnv('API_BASE_URL_WEB'),
        _readEnv('API_BASE_URL'),
        'http://localhost:8000',
      ]);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (target == 'device') {
        return _uniqueNonEmpty([
          _readEnv('API_BASE_URL_DEVICE'),
          _readEnv('API_BASE_URL_ANDROID_EMULATOR'),
          'http://10.0.2.2:8000',
          _readEnv('API_BASE_URL'),
          'http://localhost:8000',
        ]);
      }

      if (target == 'emulator') {
        return _uniqueNonEmpty([
          _readEnv('API_BASE_URL_ANDROID_EMULATOR'),
          'http://10.0.2.2:8000',
          _readEnv('API_BASE_URL_DEVICE'),
          _readEnv('API_BASE_URL'),
          'http://localhost:8000',
        ]);
      }

      return _uniqueNonEmpty([
        _readEnv('API_BASE_URL_ANDROID_EMULATOR'),
        'http://10.0.2.2:8000',
        _readEnv('API_BASE_URL_DEVICE'),
        _readEnv('API_BASE_URL'),
        'http://localhost:8000',
      ]);
    }

    return _uniqueNonEmpty([_readEnv('API_BASE_URL'), 'http://localhost:8000']);
  }

  static List<String> _uniqueNonEmpty(List<String?> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final value in values) {
      if (value == null || value.isEmpty || seen.contains(value)) {
        continue;
      }
      seen.add(value);
      result.add(value);
    }

    if (result.isEmpty) {
      return ['http://localhost:8000'];
    }

    return result;
  }

  static String? _readEnv(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static bool _isConnectivityError(DioException error) {
    return error.response == null &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.unknown);
  }

  static bool _alreadyRetriedBaseUrl(DioException error) {
    return error.requestOptions.extra['_base_url_retry'] == true;
  }

  static String? _nextBaseUrl() {
    if (_activeBaseUrlIndex >= _baseUrlCandidates.length - 1) {
      return null;
    }
    _activeBaseUrlIndex += 1;
    return _baseUrlCandidates[_activeBaseUrlIndex];
  }

  /// Clears all tokens and redirects to Login.
  static Future<void> _forceLogout() async {
    await StorageService.clearAll();
    try {
      appRouter.go(AppRoutes.login);
    } catch (_) {}
  }
}
