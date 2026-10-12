/// Mirrors backend `ActivityLogResponse` / `ActivityLogPage`.
class ActivityLog {
  final String id;
  final DateTime timestamp;
  final String? actorUserId;
  final String? actorName;
  final String eventType;
  final String severity;
  final String? targetType;
  final String? targetId;
  final String message;
  final Map<String, dynamic>? metadata;

  const ActivityLog({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.message,
    this.actorUserId,
    this.actorName,
    this.targetType,
    this.targetId,
    this.metadata,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
      actorUserId: json['actor_user_id'] as String?,
      actorName: json['actor_name'] as String?,
      eventType: json['event_type'] as String,
      severity: json['severity'] as String? ?? 'info',
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      message: json['message'] as String? ?? '',
      metadata: (json['metadata_json'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class ActivityLogPage {
  final List<ActivityLog> items;
  final int total;
  final int limit;
  final int offset;

  const ActivityLogPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory ActivityLogPage.fromJson(Map<String, dynamic> json) {
    return ActivityLogPage(
      items: (json['items'] as List)
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
    );
  }
}

class ActivityFilters {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? eventType;
  final String? severity;

  const ActivityFilters({
    this.dateFrom,
    this.dateTo,
    this.eventType,
    this.severity,
  });

  ActivityFilters copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? eventType,
    String? severity,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearEventType = false,
    bool clearSeverity = false,
  }) {
    return ActivityFilters(
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      eventType: clearEventType ? null : (eventType ?? this.eventType),
      severity: clearSeverity ? null : (severity ?? this.severity),
    );
  }
}

const kActivityEventTypes = <String>[
  'auth',
  'job',
  'printer',
  'file',
  'notification',
  'anomaly',
  'admin',
];

const kActivitySeverities = <String>['info', 'success', 'warning', 'error'];
