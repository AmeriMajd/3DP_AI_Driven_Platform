import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../domain/recommend_request.dart';
import '../domain/recommendation_result.dart';
import 'recommendation_repository.dart';

class RecommendationRepositoryImpl implements RecommendationRepository {
  final Dio _dio = DioClient.instance;

  /// POST /recommend/
  @override
  Future<RecommendationResult> createRecommendation(
      RecommendRequest request) async {
    try {
      final response = await _dio.post(
        '/recommend/',
        data: request.toJson(),
      );
      return RecommendationResult.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// PATCH /recommend/{id}/rate
  @override
  Future<RecommendationResult> rateRecommendation(
      String id, int rating) async {
    try {
      final response = await _dio.patch(
        '/recommend/$id/rate',
        data: {'rating': rating},
      );
      return RecommendationResult.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// PATCH /recommend/{id}/parameters
  @override
  Future<RecommendationResult> updateParameters(
      String id, Map<String, dynamic> params) async {
    try {
      final response = await _dio.patch(
        '/recommend/$id/parameters',
        data: params,
      );
      return RecommendationResult.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// GET /recommend/history
  @override
  Future<List<RecommendationResult>> getHistory() async {
    try {
      final response = await _dio.get('/recommend/history');
      final data = response.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items
          .map((i) =>
              RecommendationResult.fromJson(i as Map<String, dynamic>))
          .toList();
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
            return 'File not found';
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
