import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/users_repository_impl.dart';
import '../../domain/users_repository.dart';
import '../viewmodels/users_viewmodel.dart';

final usersRepositoryProvider = Provider<UsersRepository>(
  (_) => UsersRepositoryImpl(),
);

final usersViewModelProvider =
    StateNotifierProvider.autoDispose<UsersViewModel, UsersState>((ref) {
  return UsersViewModel(ref.read(usersRepositoryProvider));
});

final pendingInvitationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(usersRepositoryProvider).getInvitations();
});
