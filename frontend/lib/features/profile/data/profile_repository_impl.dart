import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../domain/profile_repository.dart';
import '../domain/profile_user.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final Dio _dio = DioClient.instance;

  @override
  Future<ProfileUser> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return ProfileUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<ProfileUser> updateProfile({String? fullName, String? email}) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (email != null) body['email'] = email;

      final response = await _dio.patch('/auth/me', data: body);
      return ProfileUser.fromJson({
        ...response.data as Map<String, dynamic>,
        'stats': {'files_uploaded': 0, 'recommendations_count': 0, 'jobs_submitted': 0},
      });
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.patch('/auth/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> revokeAllSessions() async {
    try {
      await _dio.delete('/auth/me/sessions');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) return first['msg']?.toString() ?? 'Validation error';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network.';
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Check your network.';
      default:
        return e.message ?? 'An unexpected error occurred.';
    }
  }
}
