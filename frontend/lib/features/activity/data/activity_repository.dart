import 'package:dio/dio.dart';

import '../../../shared/services/dio_client.dart';
import '../domain/activity_log.dart';

class ActivityRepository {
  final Dio _dio = DioClient.instance;

  Future<ActivityLogPage> list({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? eventType,
    String? severity,
    String? actorUserId,
    String? targetType,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (dateFrom != null) 'date_from': dateFrom.toUtc().toIso8601String(),
      if (dateTo != null) 'date_to': dateTo.toUtc().toIso8601String(),
      if (eventType != null) 'event_type': eventType,
      if (severity != null) 'severity': severity,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (targetType != null) 'target_type': targetType,
    };
    final r = await _dio.get('/admin/activity', queryParameters: qp);
    return ActivityLogPage.fromJson(r.data as Map<String, dynamic>);
  }
}
