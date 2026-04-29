import '../domain/job.dart';
import 'job_repository.dart';

// TODO(Sem3): implement with real Dio client once Dev A delivers the API
class JobRepositoryImpl implements JobRepository {
  @override
  Future<Job> submitJob({
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
    int priority = 3,
  }) => throw UnimplementedError('Switch USE_MOCK_JOBS=false after API is ready');

  @override
  Future<List<Job>> getMyJobs() => throw UnimplementedError();

  @override
  Future<Job> getJobById(String id) => throw UnimplementedError();

  @override
  Future<Job> cancelJob(String id) => throw UnimplementedError();

  @override
  Future<List<Job>> getAllJobs({String? status, String? printerId}) =>
      throw UnimplementedError();

  @override
  Future<Job> suspendJob(String id) => throw UnimplementedError();

  @override
  Future<Job> resumeJob(String id) => throw UnimplementedError();
}
