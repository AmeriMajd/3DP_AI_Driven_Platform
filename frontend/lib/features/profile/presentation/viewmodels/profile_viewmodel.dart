import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/services/storage_service.dart';
import '../../domain/profile_repository.dart';
import '../../domain/profile_state.dart';

class ProfileViewModel extends StateNotifier<ProfileState> {
  final ProfileRepository _repo;

  ProfileViewModel(this._repo) : super(const ProfileState());

  Future<void> loadProfile() async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true);
    try {
      final user = await _repo.getMe();
      state = state.copyWith(status: ProfileStatus.success, user: user);
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateName(String fullName) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true, clearSuccess: true);
    try {
      await _repo.updateProfile(fullName: fullName);
      // Keep existing user data, patch only fullName (PATCH /me returns UserResponse without stats)
      final userWithStats = state.user?.copyWith(fullName: fullName) ?? state.user;
      await StorageService.saveFullName(fullName);
      state = state.copyWith(
        status: ProfileStatus.success,
        user: userWithStats,
        successMessage: 'Name updated successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateEmail(String email) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true, clearSuccess: true);
    try {
      await _repo.updateProfile(email: email);
      final userWithEmail = state.user?.copyWith(email: email);
      state = state.copyWith(
        status: ProfileStatus.success,
        user: userWithEmail,
        successMessage: 'Email updated successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true, clearSuccess: true);
    try {
      await _repo.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(
        status: ProfileStatus.success,
        successMessage: 'Password changed successfully',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> revokeAllSessions() async {
    state = state.copyWith(status: ProfileStatus.loading, clearError: true, clearSuccess: true);
    try {
      await _repo.revokeAllSessions();
      state = state.copyWith(
        status: ProfileStatus.success,
        successMessage: 'All sessions revoked',
      );
    } catch (e) {
      state = state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}
