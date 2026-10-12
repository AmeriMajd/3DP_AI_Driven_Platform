// Models mirroring backend `/admin/dashboard/*` payloads.

class KpiItem {
  final double value;
  final double deltaPct;
  final String sub;

  const KpiItem({required this.value, required this.deltaPct, required this.sub});

  factory KpiItem.fromJson(Map<String, dynamic> j) => KpiItem(
        value: (j['value'] as num).toDouble(),
        deltaPct: (j['delta_pct'] as num).toDouble(),
        sub: j['sub'] as String? ?? '',
      );
}

class DashboardKpis {
  final KpiItem activeJobs;
  final KpiItem revenueToday;
  final KpiItem successRate;
  final KpiItem queueDepth;

  const DashboardKpis({
    required this.activeJobs,
    required this.revenueToday,
    required this.successRate,
    required this.queueDepth,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> j) => DashboardKpis(
        activeJobs: KpiItem.fromJson(j['active_jobs'] as Map<String, dynamic>),
        revenueToday: KpiItem.fromJson(j['revenue_today'] as Map<String, dynamic>),
        successRate: KpiItem.fromJson(j['success_rate'] as Map<String, dynamic>),
        queueDepth: KpiItem.fromJson(j['queue_depth'] as Map<String, dynamic>),
      );
}

class RevenuePoint {
  final DateTime date;
  final double value;
  const RevenuePoint({required this.date, required this.value});
  factory RevenuePoint.fromJson(Map<String, dynamic> j) => RevenuePoint(
        date: DateTime.parse(j['date'] as String),
        value: (j['value'] as num).toDouble(),
      );
}

class JobsByStatusPoint {
  final DateTime date;
  final int completed;
  final int failed;
  final int canceled;
  const JobsByStatusPoint({
    required this.date,
    required this.completed,
    required this.failed,
    required this.canceled,
  });
  factory JobsByStatusPoint.fromJson(Map<String, dynamic> j) => JobsByStatusPoint(
        date: DateTime.parse(j['date'] as String),
        completed: (j['completed'] as num).toInt(),
        failed: (j['failed'] as num).toInt(),
        canceled: (j['canceled'] as num).toInt(),
      );
}

class ActiveJobItem {
  final String id;
  final String userName;
  final String printerName;
  final String? file;
  final String status;
  final double progressPct;
  final double? estimatedCost;
  final int? estimatedDurationS;
  final int? timeLeftSeconds;
  final DateTime submittedAt;

  const ActiveJobItem({
    required this.id,
    required this.userName,
    required this.printerName,
    required this.file,
    required this.status,
    required this.progressPct,
    required this.estimatedCost,
    required this.estimatedDurationS,
    required this.timeLeftSeconds,
    required this.submittedAt,
  });

  factory ActiveJobItem.fromJson(Map<String, dynamic> j) => ActiveJobItem(
        id: j['id'] as String,
        userName: j['user_name'] as String? ?? '—',
        printerName: j['printer_name'] as String? ?? '—',
        file: j['file'] as String?,
        status: j['status'] as String,
        progressPct: (j['progress_pct'] as num?)?.toDouble() ?? 0.0,
        estimatedCost: (j['estimated_cost'] as num?)?.toDouble(),
        estimatedDurationS: (j['estimated_duration_s'] as num?)?.toInt(),
        timeLeftSeconds: (j['time_left_seconds'] as num?)?.toInt(),
        submittedAt: DateTime.parse(j['submitted_at'] as String),
      );
}

class RecentJobItem {
  final String id;
  final String userName;
  final String? printerName;
  final String status;
  final double? estimatedCost;
  final int? durationS;
  final DateTime submittedAt;

  const RecentJobItem({
    required this.id,
    required this.userName,
    required this.printerName,
    required this.status,
    required this.estimatedCost,
    required this.durationS,
    required this.submittedAt,
  });

  factory RecentJobItem.fromJson(Map<String, dynamic> j) => RecentJobItem(
        id: j['id'] as String,
        userName: j['user_name'] as String? ?? '—',
        printerName: j['printer_name'] as String?,
        status: j['status'] as String,
        estimatedCost: (j['estimated_cost'] as num?)?.toDouble(),
        durationS: (j['duration_s'] as num?)?.toInt(),
        submittedAt: DateTime.parse(j['submitted_at'] as String),
      );
}

class TopUserItem {
  final String userId;
  final String fullName;
  final double totalCost;
  final int jobsCount;

  const TopUserItem({
    required this.userId,
    required this.fullName,
    required this.totalCost,
    required this.jobsCount,
  });

  factory TopUserItem.fromJson(Map<String, dynamic> j) => TopUserItem(
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String? ?? '—',
        totalCost: (j['total_cost'] as num).toDouble(),
        jobsCount: (j['jobs_count'] as num).toInt(),
      );
}
