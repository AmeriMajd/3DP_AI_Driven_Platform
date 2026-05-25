import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/activity_repository.dart';
import '../viewmodels/activity_viewmodel.dart';

final activityRepoProvider = Provider<ActivityRepository>((_) => ActivityRepository());

final activityViewModelProvider =
    StateNotifierProvider.autoDispose<ActivityViewModel, ActivityState>(
  (ref) => ActivityViewModel(ref.read(activityRepoProvider)),
);
