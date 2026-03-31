import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/storage_service.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_repository_impl.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState());

  Future<void> adminSignup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.adminSignup(
        fullName: fullName,
        email: email,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Admin account created successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> generateInvite({
    required String email,
    required String role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final link = await _repo.generateInvite(email: email, role: role);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: link, // ← le vrai lien du backend
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Met à jour l'état avec les données pré-remplies (email, role, expires_at).
  Future<Map<String, dynamic>?> validateInvite({required String token}) async {
    try {
      final data = await _repo.validateInvite(token: token);
      return data;
    } catch (e) {
      return null;
    }
  }

  Future<void> register({
    required String token,
    required String fullName,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.register(
        token: token,
        fullName: fullName,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Account created. Welcome!',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.login(email: email, password: password);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Welcome back!',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> forgotPassword({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.forgotPassword(email: email);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Reset link sent',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.resetPassword(token: token, newPassword: newPassword);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Password reset successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>?> validateResetToken({
    required String token,
  }) async {
    try {
      return await _repo.validateResetToken(token: token);
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _repo.logout();
      state = const AuthState(); // reset complet
    } catch (e) {
      // logout local même si backend échoue
      await StorageService.clearAll();
      state = const AuthState();
    }
  }

  void reset() => state = const AuthState();
}
