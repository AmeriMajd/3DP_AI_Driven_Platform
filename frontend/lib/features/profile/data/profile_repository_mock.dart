import '../domain/profile_repository.dart';
import '../domain/profile_user.dart';

/// In-memory profile used by the public portfolio demo.
class ProfileRepositoryMock implements ProfileRepository {
  ProfileUser _user = ProfileUser(
    id: 'demo-operator-001',
    email: 'demo@printai.dev',
    fullName: 'Demo Operator',
    role: 'admin',
    createdAt: DateTime(2026, 1, 15),
    lastLogin: DateTime.now().subtract(const Duration(minutes: 3)),
    stats: const ProfileStats(
      filesUploaded: 18,
      recommendationsCount: 27,
      jobsSubmitted: 11,
    ),
  );

  @override
  Future<ProfileUser> getMe() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _user;
  }

  @override
  Future<ProfileUser> updateProfile({String? fullName, String? email}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _user = _user.copyWith(fullName: fullName, email: email);
    return _user;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
  }

  @override
  Future<void> revokeAllSessions() async {
    await Future.delayed(const Duration(milliseconds: 250));
  }
}
