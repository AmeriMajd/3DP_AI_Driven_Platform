import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../../../shared/services/storage_service.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_state.dart';

class AuthViewModel extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthViewModel(this._repo) : super(const AuthState());

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
        successMessage: link,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

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
      state = const AuthState();
    } catch (e) {
      await StorageService.clearAll();
      state = const AuthState();
    }
  }

  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final initialized = await _repo.checkSystemStatus();
      if (!initialized) {
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.notInitialized,
        );
        return;
      }
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.initial,
        sessionStatus: SessionStatus.unauthenticated,
      );
      return;
    }

    try {
      final accessToken = await StorageService.getToken();

      if (accessToken == null || accessToken.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.unauthenticated,
        );
        return;
      }

      bool expired;
      try {
        expired = JwtDecoder.isExpired(accessToken);
      } catch (_) {
        await StorageService.clearAll();
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.unauthenticated,
        );
        return;
      }

      if (!expired) {
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.authenticated,
        );
        return;
      }

      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await StorageService.clearAll();
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.unauthenticated,
        );
        return;
      }

      final refreshed = await _repo.tryRefreshSession();
      if (refreshed) {
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.authenticated,
        );
      } else {
        await StorageService.clearAll();
        state = state.copyWith(
          status: AuthStatus.initial,
          sessionStatus: SessionStatus.unauthenticated,
        );
      }
    } catch (_) {
      await StorageService.clearAll();
      state = state.copyWith(
        status: AuthStatus.initial,
        sessionStatus: SessionStatus.unauthenticated,
      );
    }
  }

  void reset() => state = const AuthState();
}
