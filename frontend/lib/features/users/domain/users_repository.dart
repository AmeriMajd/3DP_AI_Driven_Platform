import 'user_item.dart';

abstract class UsersRepository {
  Future<List<UserItem>> getUsers();
  Future<void> deleteUser(String userId);
  Future<Map<String, dynamic>> generateInvite({required String email, required String role});
  Future<bool> sendInviteEmail({required String invitationId});
  Future<List<Map<String, dynamic>>> getInvitations();
  Future<void> cancelInvitation(String invitationId);
}
