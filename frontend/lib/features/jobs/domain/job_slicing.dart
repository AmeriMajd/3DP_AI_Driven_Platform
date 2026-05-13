class JobSlicing {
  final String jobId;
  final String? slicingJobId;
  final String? status;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final bool gcodeReady;

  const JobSlicing({
    required this.jobId,
    this.slicingJobId,
    this.status,
    this.errorMessage,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    required this.gcodeReady,
  });

  factory JobSlicing.fromJson(Map<String, dynamic> json) {
    return JobSlicing(
      jobId: json['job_id'].toString(),
      slicingJobId: json['slicing_job_id']?.toString(),
      status: json['status'] as String?,
      errorMessage: json['error_message'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      gcodeReady: json['gcode_ready'] as bool? ?? false,
    );
  }

  static const queued = 'queued';
  static const running = 'running';
  static const done = 'done';
  static const error = 'error';
  static const canceled = 'canceled';

  bool get exists => slicingJobId != null;
  bool get isActive => status == queued || status == running;
}
