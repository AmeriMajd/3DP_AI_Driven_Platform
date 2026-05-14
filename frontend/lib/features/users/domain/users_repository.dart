import 'user_item.dart';

abstract class UsersRepository {
  Future<List<UserItem>> getUsers();
  Future<void> deleteUser(String userId);
  Future<List<Map<String, dynamic>>> getInvitations();
  Future<void> cancelInvitation(String invitationId);
}
