import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/profile_repository.dart';
import '../../domain/profile_state.dart';
import '../viewmodels/profile_viewmodel.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => ProfileRepositoryImpl(),
);

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, ProfileState>(
  (ref) => ProfileViewModel(ref.read(profileRepositoryProvider)),
);
