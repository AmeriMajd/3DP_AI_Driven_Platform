import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../domain/job.dart';
import 'job_repository.dart';

class JobRepositoryImpl implements JobRepository {
  final Dio _dio = DioClient.instance;

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
  Future<Job> getJobById(String id) async {
    try {
      final response = await _dio.get('/jobs/$id');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Job> cancelJob(String id) async {
    try {
      final response = await _dio.patch('/jobs/$id/cancel');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<List<Job>> getAllJobs({String? status, String? printerId}) =>
      throw UnimplementedError();

  @override
  Future<Job> suspendJob(String id) async {
    try {
      final response = await _dio.patch('/jobs/$id/suspend');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Job> resumeJob(String id) => throw UnimplementedError();
}
