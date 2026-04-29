import '../domain/job.dart';

abstract class JobRepository {
  Future<Job> submitJob({
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
    int priority = 3,
  });

  Future<List<Job>> getMyJobs();

  Future<Job> getJobById(String id);

  Future<Job> cancelJob(String id);

  // Admin only
  Future<List<Job>> getAllJobs({String? status, String? printerId});
  Future<Job> suspendJob(String id);
  Future<Job> resumeJob(String id);
}
