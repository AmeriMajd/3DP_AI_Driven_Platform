import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/auth_repository_mock.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryMock();
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
      final token = await _repo.generateInvite(email: email, role: role);
      state = state.copyWith(
        status: AuthStatus.success,
        successMessage: 'Invitation sent — Token: $token',
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
  /// Met à jour l'état avec les données pré-remplies (email, role, expires_at).
Future<Map<String, dynamic>?> validateInvite({
  required String token,
}) async {
  state = state.copyWith(status: AuthStatus.loading);
  try {
    final data = await _repo.validateInvite(token: token);
    state = state.copyWith(status: AuthStatus.initial);
    return data;
  } catch (e) {
    state = state.copyWith(
      status: AuthStatus.error,
      errorMessage: e.toString(),
    );
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

  void reset() => state = const AuthState();
}