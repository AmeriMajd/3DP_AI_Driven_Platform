import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_item.dart';
import '../../domain/users_repository.dart';

class UsersState {
  final List<UserItem> users;
  final bool isLoading;
  final String? error;
  final Set<String> deletingIds;

  // Invite sub-state
  final bool inviteLoading;
  final String? inviteError;
  final String? inviteId;
  final String? inviteToken;
  final String? inviteEmail;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.deletingIds = const {},
    this.inviteLoading = false,
    this.inviteError,
    this.inviteId,
    this.inviteToken,
    this.inviteEmail,
  });

  UsersState copyWith({
    List<UserItem>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? deletingIds,
    bool? inviteLoading,
    String? inviteError,
    bool clearInviteError = false,
    String? inviteId,
    String? inviteToken,
    String? inviteEmail,
  }) =>
      UsersState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        deletingIds: deletingIds ?? this.deletingIds,
        inviteLoading: inviteLoading ?? this.inviteLoading,
        inviteError: clearInviteError ? null : (inviteError ?? this.inviteError),
        inviteId: inviteId ?? this.inviteId,
        inviteToken: inviteToken ?? this.inviteToken,
        inviteEmail: inviteEmail ?? this.inviteEmail,
      );
}

class UsersViewModel extends StateNotifier<UsersState> {
  final UsersRepository _repo;

  UsersViewModel(this._repo) : super(const UsersState()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await _repo.getUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> generateInvite({
    required String email,
    required String role,
  }) async {
    state = state.copyWith(inviteLoading: true, clearInviteError: true);
    try {
      final data = await _repo.generateInvite(email: email, role: role);
      state = state.copyWith(
        inviteLoading: false,
        inviteId: data['id']?.toString(),
        inviteToken: data['token'] as String?,
        inviteEmail: email,
      );
    } catch (e) {
      state = state.copyWith(
        inviteLoading: false,
        inviteError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> sendInviteEmail({required String invitationId}) async {
    state = state.copyWith(inviteLoading: true, clearInviteError: true);
    try {
      await _repo.sendInviteEmail(invitationId: invitationId);
      state = state.copyWith(inviteLoading: false);
    } catch (e) {
      state = state.copyWith(
        inviteLoading: false,
        inviteError: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void resetInviteState() {
    state = UsersState(
      users: state.users,
      isLoading: state.isLoading,
      error: state.error,
      deletingIds: state.deletingIds,
    );
  }

  Future<bool> deleteUser(String userId) async {
    state = state.copyWith(deletingIds: {...state.deletingIds, userId});
    try {
      await _repo.deleteUser(userId);
      final updated = state.users.map((u) {
        if (u.id != userId) return u;
        return UserItem(
          id: u.id,
          fullName: u.fullName,
          email: u.email,
          role: u.role,
          isActive: false,
          createdAt: u.createdAt,
          jobsCount: u.jobsCount,
        );
      }).toList();
      state = state.copyWith(
        users: updated,
        deletingIds: state.deletingIds.difference({userId}),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        deletingIds: state.deletingIds.difference({userId}),
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}
