import '../domain/job.dart';
import 'job_repository.dart';

// TODO: implement with real Dio client once jobs API is ready.
// POST /jobs  body: { stl_file_id, recommendation_id, stl_file_name,
//                     priority, printer_id (null = auto-assign) }
// Response must include: id, status, estimated_duration_s, estimated_cost, ...
class JobRepositoryImpl implements JobRepository {
  @override
  Future<Job> submitJob({
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
    int priority = 3,
    String? printerId, // null = auto-assign
  }) => throw UnimplementedError('Jobs API not yet implemented');

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
