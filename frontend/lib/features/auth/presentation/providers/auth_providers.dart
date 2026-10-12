import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/demo_mode.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/auth_repository_mock.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_state.dart';
import '../viewmodels/auth_viewmodel.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return isDemoMode ? AuthRepositoryMock() : AuthRepositoryImpl();
});

final authViewModelProvider =
    StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(ref.read(authRepositoryProvider));
});

final invitationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.read(authRepositoryProvider).getInvitations();
});
