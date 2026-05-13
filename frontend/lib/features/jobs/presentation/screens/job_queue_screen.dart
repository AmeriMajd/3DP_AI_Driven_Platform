import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../printers/domain/printer.dart';
import '../../../printers/domain/printer_filter.dart';
import '../../../printers/providers/printer_providers.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';

class JobQueueScreen extends ConsumerStatefulWidget {
  const JobQueueScreen({super.key});

  @override
  ConsumerState<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends ConsumerState<JobQueueScreen> {
  String? _filter; // null = All

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(myJobsProvider);
    final printers =
        ref.watch(printersListProvider(const PrinterFilter())).valueOrNull ??
            const <Printer>[];
    final printerById = {for (final p in printers) p.id: p};
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            error: e.toString(),
            onRetry: () => ref.invalidate(myJobsProvider),
          ),
          data: (jobs) {
            final active = jobs.where((j) => j.isActive).toList();
            final featured = active.isNotEmpty ? active.first : null;
            final filtered = _filter == null
                ? jobs
                : jobs.where((j) {
                    if (_filter == Job.queued) {
                      return j.status == Job.queued ||
                          j.status == Job.scheduled;
                    }
                    return j.status == _filter;
                  }).toList();

            final grouped = _groupByDay(filtered);

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(myJobsProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      activeCount: active.length,
                      totalCount: jobs.length,
                      isAdmin: isAdmin,
                    ),
                  ),
                  if (featured != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _NowPrintingCard(
                          job: featured,
                          printer: printerById[featured.printerId],
                          onTap: () => context.push(
                            '/jobs/${featured.id}',
                            extra: featured,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _FilterChips(
                      jobs: jobs,
                      selected: _filter,
                      onSelect: (s) => setState(() => _filter = s),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final section = grouped[i];
                            return _Section(
                              title: section.title,
                              count: section.jobs.length,
                              jobs: section.jobs,
                              printerById: printerById,
                            );
                          },
                          childCount: grouped.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<_DaySection> _groupByDay(List<Job> jobs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final t = <Job>[];
    final y = <Job>[];
    final e = <Job>[];

    DateTime keyOf(Job j) => j.endedAt ?? j.startedAt ?? j.submittedAt;

    final sorted = [...jobs]..sort((a, b) => keyOf(b).compareTo(keyOf(a)));

    for (final j in sorted) {
      final d = keyOf(j);
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        t.add(j);
      } else if (day == yesterday) {
        y.add(j);
      } else {
        e.add(j);
      }
    }
    return [
      if (t.isNotEmpty) _DaySection('TODAY', t),
      if (y.isNotEmpty) _DaySection('YESTERDAY', y),
      if (e.isNotEmpty) _DaySection('EARLIER', e),
    ];
  }
}

class _DaySection {
  final String title;
  final List<Job> jobs;
  const _DaySection(this.title, this.jobs);
}

class _Header extends ConsumerWidget {
  final int activeCount;
  final int totalCount;
  final bool isAdmin;

  const _Header({
    required this.activeCount,
    required this.totalCount,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jobs',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$activeCount active',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(
                        text: '  ·  ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextSpan(
                        text: '$totalCount total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(Icons.search_rounded, () {}),
          const SizedBox(width: 8),
          _iconBtn(
            Icons.refresh_rounded,
            () => ref.invalidate(myJobsProvider),
            tint: AppColors.primary,
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            _iconBtn(
              Icons.admin_panel_settings_outlined,
              () => context.push(AppRoutes.jobAdmin),
              tint: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? tint}) {
    return Material(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 18, color: tint ?? AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _NowPrintingCard extends StatelessWidget {
  final Job job;
  final Printer? printer;
  final VoidCallback onTap;

  const _NowPrintingCard({
    required this.job,
    required this.printer,
    required this.onTap,
  });

  String _formatRemaining() {
    int? secs = job.timeLeftSeconds;
    if (secs == null &&
        job.estimatedDurationS != null &&
        job.startedAt != null) {
      secs = job.estimatedDurationS! -
          DateTime.now().difference(job.startedAt!).inSeconds;
    }
    if (secs == null || secs <= 0) return '—';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  @override
  Widget build(BuildContext context) {
    final pct = job.progressPct.clamp(0, 100).toDouble();
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'NOW PRINTING',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'L —/—',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'on ${printer?.name ?? '—'} · —',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatRemaining(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<Job> jobs;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _FilterChips({
    required this.jobs,
    required this.selected,
    required this.onSelect,
  });

  int _count(String? key) {
    if (key == null) return jobs.length;
    if (key == Job.queued) {
      return jobs
          .where((j) => j.status == Job.queued || j.status == Job.scheduled)
          .length;
    }
    return jobs.where((j) => j.status == key).length;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('All', null, _count(null)),
            _chip('Queued', Job.queued, _count(Job.queued)),
            _chip('Completed', Job.completed, _count(Job.completed)),
            _chip('Cancelled', Job.canceled, _count(Job.canceled)),
            _chip('Failed', Job.failed, _count(Job.failed)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value, int count) {
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.cardLight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Job> jobs;
  final Map<String, Printer> printerById;

  const _Section({
    required this.title,
    required this.count,
    required this.jobs,
    required this.printerById,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        ...jobs.map(
          (j) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _JobRow(
              job: j,
              printer: printerById[j.printerId],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  final Job job;
  final Printer? printer;
  const _JobRow({required this.job, this.printer});

  ({IconData icon, Color bg, Color fg}) _leading() {
    switch (job.status) {
      case Job.completed:
        return (
          icon: Icons.check_rounded,
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF059669),
        );
      case Job.canceled:
        return (
          icon: Icons.close_rounded,
          bg: const Color(0xFFFEE2E2),
          fg: AppColors.error,
        );
      case Job.failed:
        return (
          icon: Icons.error_outline_rounded,
          bg: const Color(0xFFFEE2E2),
          fg: AppColors.error,
        );
      case Job.queued:
      case Job.scheduled:
        return (
          icon: Icons.menu_rounded,
          bg: const Color(0xFFFEF3C7),
          fg: AppColors.warning,
        );
      case Job.printing:
        return (
          icon: Icons.print_rounded,
          bg: const Color(0xFFEDE9FE),
          fg: AppColors.primary,
        );
      case Job.paused:
        return (
          icon: Icons.pause_rounded,
          bg: const Color(0xFFF3F4F6),
          fg: AppColors.textSecondary,
        );
      default:
        return (
          icon: Icons.help_outline_rounded,
          bg: const Color(0xFFF3F4F6),
          fg: AppColors.textSecondary,
        );
    }
  }

  ({String text, Color bg, Color fg}) _pill() {
    switch (job.status) {
      case Job.queued:
      case Job.scheduled:
        return (
          text: 'QUEUED',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
        );
      case Job.printing:
        return (
          text: 'PRINTING',
          bg: const Color(0xFFEDE9FE),
          fg: AppColors.primary,
        );
      case Job.completed:
        return (
          text: 'COMPLETED',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF059669),
        );
      case Job.canceled:
        return (
          text: 'CANCELLED',
          bg: const Color(0xFFFEE2E2),
          fg: AppColors.error,
        );
      case Job.failed:
        return (
          text: 'FAILED',
          bg: const Color(0xFFFEE2E2),
          fg: AppColors.error,
        );
      case Job.paused:
        return (
          text: 'PAUSED',
          bg: const Color(0xFFF3F4F6),
          fg: AppColors.textSecondary,
        );
      default:
        return (
          text: job.status.toUpperCase(),
          bg: const Color(0xFFF3F4F6),
          fg: AppColors.textSecondary,
        );
    }
  }

  String _duration() {
    final s = job.actualDurationS ?? job.estimatedDurationS;
    if (s == null) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _timestamp() {
    final d = job.endedAt ?? job.startedAt ?? job.submittedAt;
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays >= 2) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  String _metaTail() {
    final dur = _duration();
    final p = printer?.name ?? '—';
    if (job.status == Job.queued || job.status == Job.scheduled) {
      return '$p · #${job.priority}';
    }
    if (job.errorMessage != null && job.errorMessage!.isNotEmpty) {
      return '$p · ${job.errorMessage}';
    }
    if (dur.isNotEmpty) return '$p · $dur';
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final lead = _leading();
    final pill = _pill();

    return Material(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/jobs/${job.id}', extra: job),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: lead.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(lead.icon, size: 18, color: lead.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timestamp(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pill.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pill.text,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: pill.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _metaTail(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: job.errorMessage != null &&
                                      job.status == Job.canceled
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.print_outlined,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No jobs yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Submit a recommendation to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
