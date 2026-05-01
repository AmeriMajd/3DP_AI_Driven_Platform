import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/job_repository.dart';
import '../../data/mock_job_repository.dart';
import '../../data/job_repository_impl.dart';
import '../../domain/job.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  // flutter run --dart-define=USE_MOCK_JOBS=false  →  switches to real API
  const useMock =
      String.fromEnvironment('USE_MOCK_JOBS', defaultValue: 'false') != 'false';
  return useMock ? MockJobRepository() : JobRepositoryImpl();
});

final myJobsProvider = FutureProvider<List<Job>>((ref) {
  return ref.watch(jobRepositoryProvider).getMyJobs();
});

final jobDetailProvider =
    FutureProvider.family<Job, String>((ref, id) {
  return ref.watch(jobRepositoryProvider).getJobById(id);
});

// ── Admin ─────────────────────────────────────────────────────────────────────

class AdminJobsFilter {
  final String? status;
  final String? printerId;

  const AdminJobsFilter({this.status, this.printerId});

  @override
  bool operator ==(Object other) =>
      other is AdminJobsFilter &&
      other.status == status &&
      other.printerId == printerId;

  @override
  int get hashCode => Object.hash(status, printerId);
}

final allJobsProvider =
    FutureProvider.autoDispose.family<List<Job>, AdminJobsFilter>((ref, filter) {
  return ref.watch(jobRepositoryProvider).getAllJobs(
        status: filter.status,
        printerId: filter.printerId,
      );
});
