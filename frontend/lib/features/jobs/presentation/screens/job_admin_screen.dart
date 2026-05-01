import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';
import '../widgets/job_card.dart';

class JobAdminScreen extends ConsumerStatefulWidget {
  const JobAdminScreen({super.key});

  @override
  ConsumerState<JobAdminScreen> createState() => _JobAdminScreenState();
}

class _JobAdminScreenState extends ConsumerState<JobAdminScreen> {
  String? _statusFilter;
  String? _printerFilter;

  static const _allStatuses = [
    Job.queued,
    Job.scheduled,
    Job.printing,
    Job.paused,
    Job.completed,
    Job.failed,
    Job.canceled,
  ];

  AdminJobsFilter get _filter =>
      AdminJobsFilter(status: _statusFilter, printerId: _printerFilter);

  void _clearPrinterFilter() => setState(() => _printerFilter = null);

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(allJobsProvider(_filter));

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, jobsAsync),
            _buildStatusFilters(),
            if (_printerFilter != null) _buildPrinterFilterBadge(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(jobsAsync)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<List<Job>> jobsAsync) {
    final count = jobsAsync.valueOrNull?.length ?? 0;
    final subtitle = _statusFilter == null && _printerFilter == null
        ? '$count jobs total · pull to refresh'
        : '$count jobs matching filters';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1C1C1E)),
            onPressed: () => context.pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Jobs',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black),
                ),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Color(0xFF4B6BFB), size: 22),
            onPressed: () => ref.invalidate(allJobsProvider(_filter)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _StatusChip(
            label: 'All',
            isActive: _statusFilter == null,
            color: const Color(0xFF4B6BFB),
            onTap: () => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: 8),
          ..._allStatuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _StatusChip(
                  label: _statusLabel(s),
                  isActive: _statusFilter == s,
                  color: _statusColor(s),
                  onTap: () => setState(
                      () => _statusFilter = _statusFilter == s ? null : s),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPrinterFilterBadge() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.precision_manufacturing_outlined,
              size: 13, color: Color(0xFF4B6BFB)),
          const SizedBox(width: 4),
          Text(
            'Printer: $_printerFilter',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B6BFB)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _clearPrinterFilter,
            child: const Icon(Icons.close_rounded,
                size: 14, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Job>> jobsAsync) {
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        error: e.toString(),
        onRetry: () => ref.invalidate(allJobsProvider(_filter)),
      ),
      data: (jobs) {
        if (jobs.isEmpty) return const _EmptyState();
        return RefreshIndicator(
          color: const Color(0xFF4B6BFB),
          onRefresh: () async => ref.invalidate(allJobsProvider(_filter)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: jobs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _AdminJobCard(
              job: jobs[i],
              onTap: () => context.push('/jobs/${jobs[i].id}', extra: jobs[i]),
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String s) => switch (s) {
        Job.queued => 'Queued',
        Job.scheduled => 'Scheduled',
        Job.printing => 'Printing',
        Job.paused => 'Paused',
        Job.completed => 'Completed',
        Job.failed => 'Failed',
        Job.canceled => 'Canceled',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        Job.queued => const Color(0xFF8E8E93),
        Job.scheduled => const Color(0xFF4B6BFB),
        Job.printing => const Color(0xFFFF9500),
        Job.paused => const Color(0xFFFFCC00),
        Job.completed => const Color(0xFF34C759),
        Job.failed || Job.canceled => const Color(0xFFFF3B30),
        _ => const Color(0xFF8E8E93),
      };
}

// ── Admin job card: wraps JobCard + adds suspend/resume & cancel actions ──────

class _AdminJobCard extends ConsumerStatefulWidget {
  final Job job;
  final VoidCallback onTap;

  const _AdminJobCard({
    required this.job,
    required this.onTap,
  });

  @override
  ConsumerState<_AdminJobCard> createState() => _AdminJobCardState();
}

class _AdminJobCardState extends ConsumerState<_AdminJobCard> {
  bool _suspendLoading = false;
  bool _resumeLoading = false;
  bool _cancelLoading = false;

  bool get _canSuspend =>
      widget.job.status == Job.queued || widget.job.status == Job.scheduled;
  bool get _canResume => widget.job.status == Job.paused;
  bool get _canCancel => widget.job.isCancelable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JobCard(job: widget.job, onTap: widget.onTap),
        if (_canSuspend || _canResume || _canCancel)
          Container(
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 3,
                    offset: Offset(0, 2)),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    size: 13, color: Color(0xFF8E8E93)),
                const SizedBox(width: 4),
                const Text('Admin',
                    style: TextStyle(
                        fontSize: 11, color: Color(0xFF8E8E93))),
                const Spacer(),
                if (_canSuspend)
                  _ActionButton(
                    label: 'Suspend',
                    icon: Icons.pause_circle_outline_rounded,
                    color: const Color(0xFFFFCC00),
                    loading: _suspendLoading,
                    onPressed: _suspend,
                  ),
                if (_canResume) ...[
                  _ActionButton(
                    label: 'Resume',
                    icon: Icons.play_circle_outline_rounded,
                    color: const Color(0xFF34C759),
                    loading: _resumeLoading,
                    onPressed: _resume,
                  ),
                ],
                if ((_canSuspend || _canResume) && _canCancel)
                  const SizedBox(width: 8),
                if (_canCancel)
                  _ActionButton(
                    label: 'Cancel',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFFF3B30),
                    loading: _cancelLoading,
                    onPressed: _cancel,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _suspend() async {
    setState(() => _suspendLoading = true);
    try {
      await ref.read(jobRepositoryProvider).suspendJob(widget.job.id);
      if (mounted) {
        ref.invalidate(allJobsProvider);
        _showSnack('Job suspended');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to suspend job', isError: true);
    } finally {
      if (mounted) setState(() => _suspendLoading = false);
    }
  }

  Future<void> _resume() async {
    setState(() => _resumeLoading = true);
    try {
      await ref.read(jobRepositoryProvider).resumeJob(widget.job.id);
      if (mounted) {
        ref.invalidate(allJobsProvider);
        _showSnack('Job resumed');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to resume job', isError: true);
    } finally {
      if (mounted) setState(() => _resumeLoading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelLoading = true);
    try {
      await ref.read(jobRepositoryProvider).cancelJob(widget.job.id);
      if (mounted) {
        ref.invalidate(allJobsProvider);
        _showSnack('Job cancelled');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to cancel job', isError: true);
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFFF3B30) : null,
    ));
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            )
          : Icon(icon, size: 14, color: color),
      label: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Status filter chip ────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? color : const Color(0xFF6D6D72),
          ),
        ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFD1D1D6)),
          SizedBox(height: 12),
          Text('No jobs match the filters',
              style: TextStyle(fontSize: 15, color: Color(0xFF8E8E93))),
        ],
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
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF3B30), size: 40),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4B6BFB)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
