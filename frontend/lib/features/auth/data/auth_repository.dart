abstract class AuthRepository {
  Future<void> adminSignup({
    required String fullName,
    required String email,
    required String password,
  });

  Future<String> generateInvite({
    required String email,
    required String role,
  });

  /// Valide un token d'invitation avant d'afficher le formulaire register.
  /// Retourne email, role, expires_at depuis le backend.
  Future<Map<String, dynamic>> validateInvite({
    required String token,
  });
  
  Future<void> register({
    required String token,
    required String fullName,
    required String password,
  });
}