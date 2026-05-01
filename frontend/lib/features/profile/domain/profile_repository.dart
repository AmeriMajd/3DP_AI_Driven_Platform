import 'profile_user.dart';

abstract class ProfileRepository {
  Future<ProfileUser> getMe();
  Future<ProfileUser> updateProfile({String? fullName, String? email});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> revokeAllSessions();
}
