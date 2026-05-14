abstract class AuthRepository {
  Future<bool> checkSystemStatus();

  Future<void> adminSignup({
    required String fullName,
    required String email,
    required String password,
  });

  Future<bool> generateInvite({required String email, required String role});

  Future<bool> resendInvite({required String invitationId});

  Future<List<Map<String, dynamic>>> getInvitations();

  /// Valide un token d'invitation avant d'afficher le formulaire register.
  /// Retourne email, role, expires_at depuis le backend.
  Future<Map<String, dynamic>> validateInvite({required String token});

  Future<void> register({
    required String token,
    required String fullName,
    required String password,
  });

  Future<void> login({required String email, required String password});

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<Map<String, dynamic>> validateResetToken({required String token});

  Future<void> refreshToken();

  Future<bool> tryRefreshSession();

  Future<void> logout();
}
