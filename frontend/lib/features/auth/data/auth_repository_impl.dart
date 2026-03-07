import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../../../shared/services/storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_repository.dart';

/// Implémentation réelle de [AuthRepository].
/// 
/// Connecté au backend FastAPI via [DioClient].
/// Gère 4 opérations : adminSignup, generateInvite, validateInvite, register.
/// En cas d'erreur réseau ou serveur, lance une [Exception]
/// avec le message retourné par l'API.

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio = DioClient.instance;

  //  POST /auth/admin/signup
  /// 
  /// Crée le premier compte administrateur.
  /// La [admin_secret_key] est injectée depuis .env — invisible pour l'utilisateur.
  /// 
  /// Erreurs possibles :
  /// - 400 : Email déjà utilisé
  /// - 403 : Mauvaise admin_secret_key
  /// - 422 : Validation échouée
  @override
  Future<void> adminSignup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    //await Future.delayed(const Duration(seconds: 2));
    try {
      await _dio.post(
        '/auth/admin/signup',
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'admin_secret_key': dotenv.env['ADMIN_SIGNUP_KEY'] ?? '',
          // clé injectée automatiquement — invisible pour l'utilisateur
        },
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// POST /admin/invitations
  ///
  /// Génère un token d'invitation pour un nouvel utilisateur.
  /// Endpoint protégé — réservé aux admins authentifiés.
  /// 
  /// [email] : email du futur utilisateur
  /// [role]  : 'admin' | 'operator'
  /// 
  /// Retourne le token généré par le backend.
  /// 
  /// Erreurs possibles :
  /// - 400 : Email a déjà un compte
  /// - 401 : Admin non authentifié
  /// - 403 : Accès admin requis

  @override
  Future<String> generateInvite({
    required String email,
    required String role,
  }) async {
    //await Future.delayed(const Duration(seconds: 2));
    try {
      final response = await _dio.post(
        '/admin/invitations',
        data: {
          'email': email,
          'role': role,
        },
      );
      return response.data['link'] as String;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// GET /invitations/validate?token=abc123xyz
  ///
  /// Vérifie que le token est valide, non expiré, et non utilisé.
  /// Appelé avant d'afficher le formulaire d'inscription.
  ///
  /// Retourne un Map avec email, role, expires_at pré-remplis depuis le token.
  ///
  /// Erreurs possibles :
  /// - 400 : Token invalide / expiré / déjà utilisé
  /// 
  @override
  Future<Map<String, dynamic>> validateInvite({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/invitations/validate',
        queryParameters: {'token': token},
      );
      // Backend retourne { "email": "...", "role": "operator", "expires_at": "..." }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// POST /auth/register
  ///
  /// Crée le compte utilisateur via token d'invitation.
  /// Email et role viennent du token — l'utilisateur ne les contrôle pas.
  /// L'utilisateur fournit uniquement son nom et mot de passe.
  ///
  /// Erreurs possibles :
  /// - 400 : Token invalide / expiré / déjà utilisé
  /// - 422 : Validation échouée

  @override
  Future<void> register({
    required String token,
    required String fullName,
    required String password,
  }) async {
    try {
    await _dio.post(
      '/auth/register',
      data: {
        'token': token,
        'full_name': fullName,
        'password': password,
      },
    );

    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> login ({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password':password,
        },
        
      );
      final token = response.data['access_token'] as String?;
      if (token == null){
        throw Exception(
          'Backend error: access_token missing from login response.',

        );
      }
      await StorageService.saveToken(token);

      final refreshToken = response.data['refresh_token'] as String?;
    if (refreshToken != null) {
      await StorageService.saveRefreshToken(refreshToken);
    }
      
    } on DioException catch (e) {
    throw Exception(_handleError(e));
  } 
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _dio.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Map<String, dynamic>> validateResetToken({
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        '/auth/reset-password/validate',
        queryParameters: {'token': token},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Extrait le message d'erreur lisible depuis la réponse Dio.
  String _handleError(DioException e) {
    if (e.response?.data != null) {
      final detail = e.response?.data['detail'];
      // Erreur simple : { "detail": "Email already registered" }
      if (detail is String) return detail;
      // Erreur validation 422 : { "detail": [{ "loc": [...], "msg": "..." }] }
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg'] ?? 'Validation error';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout — check your network';
      case DioExceptionType.connectionError:
        return 'Cannot reach server — is the backend running?';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond';
      default:
        return 'An unexpected error occurred';
    }
  }
}
