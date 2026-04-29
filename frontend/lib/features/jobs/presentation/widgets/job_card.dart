import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';
import 'job_status_badge.dart';

class JobCard extends ConsumerWidget {
  final Job job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrinting = job.status == Job.printing;
    final isQueued = job.status == Job.queued;
    final isCompleted = job.status == Job.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + name + chevron
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B6BFB).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.view_in_ar_rounded,
                            color: Color(0xFF4B6BFB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.displayName,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                JobStatusBadge(status: job.status),
                                const SizedBox(width: 8),
                                Text(_timeAgo(job.submittedAt),
                                    style: const TextStyle(
                                        fontSize: 12, color: Color(0xFF8E8E93))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0x4C3C3C43), size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Info pills row
                  Row(
                    children: [
                      _InfoPill(
                        icon: Icons.print_outlined,
                        label: job.printerId != null ? 'Assigned' : 'Auto-assign',
                        color: const Color(0xFF6D6D72),
                        bg: const Color(0xFFF2F2F7),
                      ),
                      const SizedBox(width: 6),
                      if (isPrinting && job.estimatedDurationS != null)
                        _InfoPill(
                          icon: Icons.access_time_rounded,
                          label: '${_formatDuration(_remaining)} left',
                          color: const Color(0xFFFF9500),
                          bg: const Color(0x1AFF9500),
                          bold: true,
                        )
                      else if (isCompleted)
                        _InfoPill(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Done',
                          color: const Color(0xFF34C759),
                          bg: const Color(0x1A34C759),
                          bold: true,
                        )
                      else if (job.estimatedDurationS != null)
                        _InfoPill(
                          icon: Icons.access_time_rounded,
                          label: 'Est. ${_formatDuration(job.estimatedDurationS!)}',
                          color: const Color(0xFF6D6D72),
                          bg: const Color(0xFFF2F2F7),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Progress bar (printing)
            if (isPrinting) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${job.progressPct.toInt()}%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF9500))),
                        _CancelButton(job: job),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: job.progressPct / 100,
                        minHeight: 5,
                        backgroundColor: const Color(0x0F000000),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFFF9500)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Cancel button only (queued)
            if (isQueued)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _CancelButton(job: job),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int get _remaining {
    if (job.estimatedDurationS == null) return 0;
    final elapsed = job.startedAt != null
        ? DateTime.now().difference(job.startedAt!).inSeconds
        : 0;
    return (job.estimatedDurationS! - elapsed).clamp(0, job.estimatedDurationS!);
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final bool bold;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}

class _CancelButton extends ConsumerStatefulWidget {
  final Job job;
  const _CancelButton({required this.job});

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _loading ? null : _cancel,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFF3B30),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Color(0xFFFF3B30)))
          : const Text('Cancel'),
    );
  }

  Future<void> _cancel() async {
    setState(() => _loading = true);
    try {
      await ref.read(jobRepositoryProvider).cancelJob(widget.job.id);
      if (mounted) {
        ref.invalidate(myJobsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel job'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
