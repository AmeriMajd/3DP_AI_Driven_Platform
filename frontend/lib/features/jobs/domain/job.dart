class Job {
  final String id;
  final String userId;
  final String stlFileId;
  final String? stlFileName;
  final String? recommendationId;
  final String? printerId;
  final String status;
  final int priority;
  final double progressPct;
  final int? estimatedDurationS;
  final int? actualDurationS;
  final double? estimatedCost;
  final DateTime submittedAt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? errorMessage;

  const Job({
    required this.id,
    required this.userId,
    required this.stlFileId,
    this.stlFileName,
    this.recommendationId,
    this.printerId,
    required this.status,
    required this.priority,
    required this.progressPct,
    this.estimatedDurationS,
    this.actualDurationS,
    this.estimatedCost,
    required this.submittedAt,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.errorMessage,
  });

  Job copyWith({
    String? status,
    double? progressPct,
    String? printerId,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    String? errorMessage,
    int? estimatedDurationS,
    int? actualDurationS,
    double? estimatedCost,
  }) {
    return Job(
      id: id,
      userId: userId,
      stlFileId: stlFileId,
      stlFileName: stlFileName,
      recommendationId: recommendationId,
      printerId: printerId ?? this.printerId,
      status: status ?? this.status,
      priority: priority,
      progressPct: progressPct ?? this.progressPct,
      estimatedDurationS: estimatedDurationS ?? this.estimatedDurationS,
      actualDurationS: actualDurationS ?? this.actualDurationS,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      submittedAt: submittedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      stlFileId: json['stl_file_id'].toString(),
      stlFileName: json['stl_file_name'] as String?,
      recommendationId: json['recommendation_id']?.toString(),
      printerId: json['printer_id']?.toString(),
      status: json['status'] as String,
      priority: (json['priority'] as num).toInt(),
      progressPct: (json['progress_pct'] as num).toDouble(),
      estimatedDurationS: (json['estimated_duration_s'] as num?)?.toInt(),
      actualDurationS: (json['actual_duration_s'] as num?)?.toInt(),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
    );
  }

  // Valid statuses
  static const queued = 'queued';
  static const scheduled = 'scheduled';
  static const printing = 'printing';
  static const completed = 'completed';
  static const failed = 'failed';
  static const canceled = 'canceled';
  static const paused = 'paused';

  bool get isCancelable =>
      status == queued || status == scheduled || status == paused;
  bool get isActive => status == printing || status == scheduled;
  bool get isFinished =>
      status == completed || status == failed || status == canceled;

  String get displayName => stlFileName ?? 'Job #${id.substring(0, 8)}';
}
