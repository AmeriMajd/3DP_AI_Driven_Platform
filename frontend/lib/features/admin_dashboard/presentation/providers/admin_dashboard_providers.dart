import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_dashboard_repository.dart';
import '../../domain/admin_dashboard_models.dart';

final adminDashboardRepoProvider =
    Provider<AdminDashboardRepository>((_) => AdminDashboardRepository());

/// Selected time range — drives revenue, jobs chart, top users.
final dashboardRangeProvider = StateProvider<String>((_) => '30d');

/// Recent-jobs filter chip.
final recentJobsFilterProvider = StateProvider<String>((_) => 'all');

final kpisProvider = FutureProvider.autoDispose<DashboardKpis>((ref) async {
  return ref.read(adminDashboardRepoProvider).getKpis();
});

final revenueProvider = FutureProvider.autoDispose<List<RevenuePoint>>((ref) async {
  final range = ref.watch(dashboardRangeProvider);
  return ref.read(adminDashboardRepoProvider).getRevenue(range);
});

final jobsByStatusProvider = FutureProvider.autoDispose<List<JobsByStatusPoint>>((ref) async {
  final range = ref.watch(dashboardRangeProvider);
  return ref.read(adminDashboardRepoProvider).getJobsByStatus(range);
});

final activeJobsProvider = FutureProvider.autoDispose<List<ActiveJobItem>>((ref) async {
  return ref.read(adminDashboardRepoProvider).getActiveJobs();
});

final recentJobsProvider = FutureProvider.autoDispose<List<RecentJobItem>>((ref) async {
  final filter = ref.watch(recentJobsFilterProvider);
  return ref.read(adminDashboardRepoProvider).getRecentJobs(filter: filter);
});

final topUsersProvider = FutureProvider.autoDispose<List<TopUserItem>>((ref) async {
  final range = ref.watch(dashboardRangeProvider);
  return ref.read(adminDashboardRepoProvider).getTopUsers(range);
});
