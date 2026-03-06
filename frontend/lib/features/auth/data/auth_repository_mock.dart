import 'auth_repository.dart';

/// Mock utilisé pour tester l'UI sans backend.
/// 
/// Simule :
/// - [adminSignup] → succès après 2s
/// - [generateInvite] → succès avec faux token
/// - [register] → erreur simulée pour tester l'état d'erreur
class AuthRepositoryMock implements AuthRepository {

  @override
  Future<void> adminSignup({
    required String fullName,
    required String email,
    required String password,

  }) async {
    await Future.delayed(const Duration(seconds: 2));
    // ✅ Simule un succès
    // throw Exception('Email already exists'); // décommente pour tester erreur
  }

  @override
  Future<String> generateInvite({
    required String email,
    required String role,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return 'tk_mock_${DateTime.now().millisecondsSinceEpoch}';
  }

 @override
  Future<Map<String, dynamic>> validateInvite({
    required String token,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    // throw Exception('Invalid or expired invitation'); // tester erreur 400
    return {
      'email': 'mike@company.com',
      'role': 'operator',
      'expires_at': DateTime.now()
          .add(const Duration(hours: 36))
          .toIso8601String(),
    };
  }

  @override
  Future<void> register({
    required String token,
    required String fullName,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    // ❌ Simule une erreur
    //throw Exception('Invalid or expired token');
  }

  @override
Future<void> login({
  required String email,
  required String password,
}) async {
  await Future.delayed(const Duration(seconds: 2));
  // throw Exception('Invalid email or password'); // tester erreur
}
@override
Future<void> forgotPassword({
    required String email
  })async {
    await Future.delayed(const Duration(seconds: 2));
  // throw Exception('Email not found'); // tester erreur 404
  }
  @override
Future<void> resetPassword({
  required String token,
  required String newPassword,
}) async {
  await Future.delayed(const Duration(seconds: 2));
  // throw Exception('Invalid or expired token'); // tester erreur
}

@override
Future<Map<String, dynamic>> validateResetToken({
  required String token,
}) async {
  await Future.delayed(const Duration(seconds: 1));
  return {
    'email': 'user@company.tn',
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 13))
        .toIso8601String(),
  };
}

}