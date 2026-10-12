import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../domain/user_item.dart';
import '../domain/users_repository.dart';

class UsersRepositoryImpl implements UsersRepository {
  final Dio _dio = DioClient.instance;

  @override
  Future<List<UserItem>> getUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      return (response.data as List)
          .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _dio.delete('/admin/users/$userId');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Map<String, dynamic>> generateInvite({
    required String email,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        '/admin/invitations',
        data: {'email': email, 'role': role},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<bool> sendInviteEmail({required String invitationId}) async {
    try {
      final response = await _dio.post('/admin/invitations/$invitationId/send-email');
      return response.data['email_sent'] as bool? ?? true;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getInvitations() async {
    try {
      final response = await _dio.get('/admin/invitations');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    try {
      await _dio.delete('/admin/invitations/$invitationId');
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
      default:
        return 'An unexpected error occurred';
    }
  }
}
