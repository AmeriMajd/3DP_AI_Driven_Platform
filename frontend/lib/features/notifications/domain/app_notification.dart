/// Domain model — mirrors `NotificationRead` schema from the backend.
///
/// Plain Dart class with manual `fromJson` to match the convention used in
/// `features/jobs/domain/job.dart` (no freezed in this project).
class AppNotification {
  final String id;
  final String userId;
  final String category; // print_job | ml_pipeline | printer_health | account_security
  final String type;
  final String severity; // info | success | warning | error
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? collapseKey;
  final List<String> deliveredChannels;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.category,
    required this.type,
    required this.severity,
    required this.title,
    this.body,
    this.data,
    this.collapseKey,
    this.deliveredChannels = const [],
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      category: category,
      type: type,
      severity: severity,
      title: title,
      body: body,
      data: data,
      collapseKey: collapseKey,
      deliveredChannels: deliveredChannels,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      category: json['category'] as String,
      type: json['type'] as String,
      severity: (json['severity'] as String?) ?? 'info',
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      collapseKey: json['collapse_key'] as String?,
      deliveredChannels: (json['delivered_channels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }

  // Categories
  static const categoryPrintJob = 'print_job';
  static const categoryMlPipeline = 'ml_pipeline';
  static const categoryPrinterHealth = 'printer_health';
  static const categoryAccountSecurity = 'account_security';

  // Severities
  static const severityInfo = 'info';
  static const severitySuccess = 'success';
  static const severityWarning = 'warning';
  static const severityError = 'error';
}

/// Filter chips on the history screen. Each value maps to a server query.
enum NotificationFilter {
  all,
  errors,
  completed,
  progress,
  system,
}

extension NotificationFilterX on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.errors:
        return 'Errors';
      case NotificationFilter.completed:
        return 'Completed';
      case NotificationFilter.progress:
        return 'Progress';
      case NotificationFilter.system:
        return 'System';
    }
  }

  /// Client-side predicate matching the chip.
  ///
  /// Filtering happens on the client because the categorization here cuts
  /// across server-side `category` + `severity` + `type` fields. A pure
  /// server filter would need extra query parameters per chip; keeping it
  /// client-side avoids that coupling while the chip set is still evolving.
  bool matches(AppNotification n) {
    switch (this) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.errors:
        return n.severity == AppNotification.severityError ||
            n.severity == AppNotification.severityWarning;
      case NotificationFilter.completed:
        return n.type.endsWith('.completed') ||
            n.type.endsWith('.done') ||
            n.severity == AppNotification.severitySuccess;
      case NotificationFilter.progress:
        return n.type.contains('progress');
      case NotificationFilter.system:
        return n.category == AppNotification.categoryPrinterHealth ||
            n.category == AppNotification.categoryAccountSecurity;
    }
  }
}
