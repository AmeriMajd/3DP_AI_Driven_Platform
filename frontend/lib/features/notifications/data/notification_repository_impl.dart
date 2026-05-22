import 'package:dio/dio.dart';

import '../../../shared/services/dio_client.dart';
import '../domain/app_notification.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final Dio _dio = DioClient.instance;

  @override
  Future<NotificationPage> list({
    DateTime? cursor,
    int limit = 30,
    bool unreadOnly = false,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        if (unreadOnly) 'unread_only': true,
        if (cursor != null) 'cursor': cursor.toUtc().toIso8601String(),
        if (category != null) 'category': category,
      };
      final response = await _dio.get('/notifications', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>)
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
      final nextRaw = data['next_cursor'] as String?;
      return NotificationPage(
        items: items,
        nextCursor: nextRaw != null ? DateTime.parse(nextRaw) : null,
        unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('/notifications/unread-count');
      return (response.data['unread_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<AppNotification> markRead(String notificationId) async {
    try {
      final response = await _dio.post('/notifications/$notificationId/read');
      return AppNotification.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<int> markAllRead() async {
    try {
      final response = await _dio.post('/notifications/read-all');
      return (response.data['affected'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceLabel,
    String? appVersion,
  }) async {
    try {
      await _dio.post('/notifications/devices', data: {
        'fcm_token': fcmToken,
        'platform': platform,
        if (deviceLabel != null) 'device_label': deviceLabel,
        if (appVersion != null) 'app_version': appVersion,
      });
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> unregisterDevice(String fcmToken) async {
    try {
      await _dio.delete('/notifications/devices/$fcmToken');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  String _handleError(DioException e) {
    if (e.response?.data != null) {
      final detail = e.response?.data['detail'];
      if (detail is String) return detail;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        return 'Cannot reach server';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout';
      default:
        switch (e.response?.statusCode) {
          case 401:
            return 'Not authenticated';
          case 403:
            return 'Access denied';
          case 404:
            return 'Notification not found';
          default:
            return 'Unexpected error';
        }
    }
  }
}
