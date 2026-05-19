import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/presentation/providers/job_providers.dart';
import '../../../recommendation/domain/recommendation_result.dart';
import '../../../recommendation/presentation/providers/recommendation_history_provider.dart';

enum _Timeframe { d7, d30, all }

final _timeframeProvider = StateProvider<_Timeframe>((_) => _Timeframe.d30);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tf = ref.watch(_timeframeProvider);
    final jobsAsync = ref.watch(myJobsProvider);
    final recosAsync = ref.watch(recommendationHistoryProvider);

    final cutoff = _cutoffFor(tf);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'History',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(context, ref, jobsAsync, recosAsync, tf, cutoff),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Job>> jobsAsync,
    AsyncValue<List<RecommendationResult>> recosAsync,
    _Timeframe tf,
    DateTime? cutoff,
  ) {
    if (jobsAsync.isLoading || recosAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (jobsAsync.hasError) {
      return _ErrorView(
        message: jobsAsync.error.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(myJobsProvider),
      );
    }
    if (recosAsync.hasError) {
      return _ErrorView(
        message: recosAsync.error.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(recommendationHistoryProvider),
      );
    }

    final allJobs = jobsAsync.value ?? const <Job>[];
    final allRecos = recosAsync.value ?? const <RecommendationResult>[];

    final jobs = allJobs.where((j) {
      if (!j.isFinished) return false;
      final ended = j.endedAt ?? j.submittedAt;
      return cutoff == null || ended.isAfter(cutoff);
    }).toList()
      ..sort((a, b) =>
          (b.endedAt ?? b.submittedAt).compareTo(a.endedAt ?? a.submittedAt));

    final recos = allRecos.where((r) {
      return cutoff == null || r.createdAt.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final completed = jobs.where((j) => j.status == Job.completed).length;
    final failed = jobs.where((j) => j.status == Job.failed).length;
    final canceled = jobs.where((j) => j.status == Job.canceled).length;
    final totalFinished = completed + failed + canceled;
    final successRate =
        totalFinished == 0 ? 0 : ((completed / totalFinished) * 100).round();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _TimeframeRow(active: tf),
        const SizedBox(height: 16),
        _KpiRow(
          jobsPrinted: completed,
          successRate: successRate,
          recosCount: recos.length,
          hasJobs: totalFinished > 0,
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Recent Jobs',
          onSeeAll: () => context.go(AppRoutes.jobQueue),
        ),
        const SizedBox(height: 8),
        if (jobs.isEmpty)
          const _EmptyMini(text: 'No finished jobs in this period.')
        else
          ...jobs.take(5).map((j) => _JobRow(
                job: j,
                onTap: () => context.push('/jobs/${j.id}', extra: j),
              )),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Recent Recommendations',
          onSeeAll: () => context.go(AppRoutes.recommendHistory),
        ),
        const SizedBox(height: 8),
        if (recos.isEmpty)
          const _EmptyMini(text: 'No recommendations in this period.')
        else
          ...recos.take(5).map((r) => _RecoRow(
                reco: r,
                onTap: () => context.push(
                  AppRoutes.recommendResult,
                  extra: r,
                ),
              )),
      ],
    );

    if (kIsWeb) return body;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(myJobsProvider);
        ref.invalidate(recommendationHistoryProvider);
      },
      child: body,
    );
  }

  DateTime? _cutoffFor(_Timeframe tf) {
    final now = DateTime.now();
    return switch (tf) {
      _Timeframe.d7 => now.subtract(const Duration(days: 7)),
      _Timeframe.d30 => now.subtract(const Duration(days: 30)),
      _Timeframe.all => null,
    };
  }
}

// ── Timeframe row ────────────────────────────────────────────────────────────

class _TimeframeRow extends ConsumerWidget {
  const _TimeframeRow({required this.active});
  final _Timeframe active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _TfChip(
          label: '7d',
          selected: active == _Timeframe.d7,
          onTap: () =>
              ref.read(_timeframeProvider.notifier).state = _Timeframe.d7,
        ),
        const SizedBox(width: 8),
        _TfChip(
          label: '30d',
          selected: active == _Timeframe.d30,
          onTap: () =>
              ref.read(_timeframeProvider.notifier).state = _Timeframe.d30,
        ),
        const SizedBox(width: 8),
        _TfChip(
          label: 'All',
          selected: active == _Timeframe.all,
          onTap: () =>
              ref.read(_timeframeProvider.notifier).state = _Timeframe.all,
        ),
      ],
    );
  }
}

class _TfChip extends StatelessWidget {
  const _TfChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── KPI row ──────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.jobsPrinted,
    required this.successRate,
    required this.recosCount,
    required this.hasJobs,
  });

  final int jobsPrinted;
  final int successRate;
  final int recosCount;
  final bool hasJobs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiTile(
            value: '$jobsPrinted',
            label: 'Jobs printed',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            value: hasJobs ? '$successRate%' : '—',
            label: 'Success rate',
            color: hasJobs && successRate >= 80
                ? AppColors.success
                : hasJobs && successRate >= 50
                    ? AppColors.warning
                    : AppColors.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _KpiTile(
            value: '$recosCount',
            label: 'Recos',
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});
  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: const Row(
            children: [
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Job row ──────────────────────────────────────────────────────────────────

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, statusLabel) = switch (job.status) {
      Job.completed => (Icons.check_circle_rounded, AppColors.success, 'Done'),
      Job.failed => (Icons.cancel_rounded, AppColors.error, 'Failed'),
      Job.canceled => (
          Icons.do_not_disturb_on_rounded,
          AppColors.textSecondary,
          'Canceled'
        ),
      _ => (Icons.help_outline_rounded, AppColors.textSecondary, job.status),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusLabel · ${_relative(job.endedAt ?? job.submittedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Reco row ─────────────────────────────────────────────────────────────────

class _RecoRow extends StatelessWidget {
  const _RecoRow({required this.reco, required this.onTap});
  final RecommendationResult reco;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tech = reco.technology ?? '—';
    final mat = reco.material ?? '—';
    final tier = reco.confidenceTier ?? 'low';
    final tierColor = switch (tier) {
      'high' => AppColors.success,
      'medium' => AppColors.warning,
      _ => AppColors.error,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tech · $mat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_tierLabel(tier)} · ${_relative(reco.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: tierColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _tierLabel(String tier) => switch (tier) {
        'high' => 'High confidence',
        'medium' => 'Moderate confidence',
        _ => 'Low confidence',
      };
}

// ── Empty / error ────────────────────────────────────────────────────────────

class _EmptyMini extends StatelessWidget {
  const _EmptyMini({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _relative(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}
