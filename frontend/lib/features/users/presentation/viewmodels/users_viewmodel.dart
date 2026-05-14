import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_item.dart';
import '../../domain/users_repository.dart';

class UsersState {
  final List<UserItem> users;
  final bool isLoading;
  final String? error;
  final Set<String> deletingIds;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.deletingIds = const {},
  });

  UsersState copyWith({
    List<UserItem>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Set<String>? deletingIds,
  }) =>
      UsersState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        deletingIds: deletingIds ?? this.deletingIds,
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

  Future<bool> deleteUser(String userId) async {
    state = state.copyWith(deletingIds: {...state.deletingIds, userId});
    try {
      await _repo.deleteUser(userId);
      state = state.copyWith(
        users: state.users.where((u) => u.id != userId).toList(),
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
