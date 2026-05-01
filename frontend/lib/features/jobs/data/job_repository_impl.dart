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
    String? printerId,
  }) async {
    try {
      final response = await _dio.post('/jobs', data: {
        'stl_file_id': stlFileId,
        'recommendation_id': recommendationId,
        'priority': priority,
      });
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<List<Job>> getMyJobs() async {
    try {
      final response = await _dio.get('/jobs');
      final list = response.data as List<dynamic>;
      return list.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

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
  Future<List<Job>> getAllJobs({String? status, String? printerId}) async {
    try {
      final response = await _dio.get('/jobs', queryParameters: {
        'status': status,
        'printer_id': printerId,
      });
      final list = response.data as List<dynamic>;
      return list.map((j) => Job.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

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
  Future<Job> resumeJob(String id) async {
    try {
      final response = await _dio.patch('/jobs/$id/resume');
      return Job.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data != null) {
      final detail = e.response?.data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg'] ?? 'Validation error';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout — check your network';
      case DioExceptionType.connectionError:
        return 'Cannot reach server — is the backend running?';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond';
      default:
        switch (e.response?.statusCode) {
          case 401:
            return 'Not authenticated';
          case 403:
            return 'Access denied';
          case 404:
            return 'Job not found';
          case 409:
            return 'Cannot perform that action — job is in an incompatible state';
          case 422:
            return 'Malformed request — please try again';
          case 500:
            return 'Server error — please try again later';
          default:
            return 'An unexpected error occurred';
        }
    }
  }
}
