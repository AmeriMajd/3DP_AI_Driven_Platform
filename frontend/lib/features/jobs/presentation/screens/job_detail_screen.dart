import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/printers/providers/printer_providers.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';
import '../widgets/job_status_badge.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  final Job? initialJob;

  const JobDetailScreen({super.key, required this.jobId, this.initialJob});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _cancelLoading = false;
  bool _showConfirm = false;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = widget.initialJob != null
        ? AsyncValue.data(widget.initialJob!)
        : ref.watch(jobDetailProvider(widget.jobId));

    return jobAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF2F2F7),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(backgroundColor: const Color(0xFFF2F2F7), elevation: 0),
        body: Center(child: Text('Error: $e')),
      ),
      data: (job) => _buildScreen(context, job),
    );
  }

  Widget _buildScreen(BuildContext context, Job job) {
    final isPrinting = job.status == Job.printing;
    final isCompleted = job.status == Job.completed;
    final isCanceled = job.status == Job.canceled || job.status == Job.failed;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _NavBar(jobId: job.id),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero card
                        _HeroCard(job: job, isPrinting: isPrinting,
                            isCompleted: isCompleted, isCanceled: isCanceled,
                            formatDuration: _formatDuration),
                        const SizedBox(height: 20),

                        // Details
                        const _SectionLabel('Details'),
                        _DetailsCard(job: job, formatDuration: _formatDuration),
                        const SizedBox(height: 20),

                        // Timeline
                        const _SectionLabel('Timeline'),
                        _TimelineCard(job: job, formatTime: _formatTime,
                            isCompleted: isCompleted),
                        const SizedBox(height: 20),

                        // Cancel button
                        if (job.isCancelable && !isCanceled)
                          _CancelButton(onTap: () => setState(() => _showConfirm = true)),
                        if (isCanceled)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x14FF3B30),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              job.status == Job.failed
                                  ? 'Job failed${job.errorMessage != null ? ': ${job.errorMessage}' : ''}'
                                  : 'This job has been cancelled',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF3B30)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Confirm sheet overlay
          if (_showConfirm) _ConfirmSheet(
            jobId: job.id,
            loading: _cancelLoading,
            onConfirm: () => _cancelJob(job),
            onDismiss: () => setState(() => _showConfirm = false),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelJob(Job job) async {
    setState(() => _cancelLoading = true);
    try {
      await ref.read(jobRepositoryProvider).cancelJob(job.id);
      ref.invalidate(myJobsProvider);
      ref.invalidate(jobDetailProvider(job.id));
      if (mounted) setState(() => _showConfirm = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }
}

class _NavBar extends StatelessWidget {
  final String jobId;
  const _NavBar({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              children: const [
                Icon(Icons.chevron_left_rounded,
                    color: Color(0xFF4B6BFB), size: 28),
                Text('Back',
                    style: TextStyle(
                        fontSize: 17,
                        color: Color(0xFF4B6BFB),
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('JOB',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8E8E93),
                        letterSpacing: 0.3)),
                Text('#${jobId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Job job;
  final bool isPrinting;
  final bool isCompleted;
  final bool isCanceled;
  final String Function(int) formatDuration;

  const _HeroCard({
    required this.job,
    required this.isPrinting,
    required this.isCompleted,
    required this.isCanceled,
    required this.formatDuration,
  });

  int get _remaining {
    if (job.estimatedDurationS == null) return 0;
    final elapsed = job.startedAt != null
        ? DateTime.now().difference(job.startedAt!).inSeconds
        : 0;
    return (job.estimatedDurationS! - elapsed).clamp(0, job.estimatedDurationS!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STL file',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                    const SizedBox(height: 2),
                    Text(job.displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              JobStatusBadge(status: job.status),
            ],
          ),
          const SizedBox(height: 14),
          if (isPrinting) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                Text('${job.progressPct.toInt()}%',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFF9500))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: job.progressPct / 100,
                minHeight: 6,
                backgroundColor: const Color(0x0F000000),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFF9500)),
              ),
            ),
            const SizedBox(height: 8),
            Text('Estimated time remaining ~ ${formatDuration(_remaining)}',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          ] else if (isCompleted)
            const Text('✓ Completed successfully',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF34C759)))
          else if (isCanceled)
            const Text('✕ Job was cancelled',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF3B30)))
          else
            const Text('Waiting for a printer to become available.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }
}

class _DetailsCard extends ConsumerWidget {
  final Job job;
  final String Function(int) formatDuration;
  const _DetailsCard({required this.job, required this.formatDuration});

  static const _priorityLabels = ['', 'Low', 'Low', 'Normal', 'High', 'Urgent'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityLabel = job.priority >= 1 && job.priority <= 5
        ? _priorityLabels[job.priority]
        : 'Normal';

    final printerLabel = job.printerId == null
        ? 'Auto-assign'
        : ref.watch(printerDetailProvider(job.printerId!)).when(
              data: (p) => p.name,
              loading: () => '…',
              error: (_, _) => 'Printer',
            );

    final rows = [
      _DetailRow(
        icon: Icons.flag_rounded,
        iconBg: const Color(0x1FFF9500),
        iconColor: const Color(0xFFFF9500),
        label: 'Priority',
        value: '$priorityLabel · ${job.priority}',
        valueColor: const Color(0xFFFF9500),
      ),
      _DetailRow(
        icon: Icons.print_rounded,
        iconBg: const Color(0x1F4B6BFB),
        iconColor: const Color(0xFF4B6BFB),
        label: 'Printer',
        value: printerLabel,
      ),
      if (job.estimatedDurationS != null)
        _DetailRow(
          icon: Icons.access_time_rounded,
          iconBg: const Color(0x1F4B6BFB),
          iconColor: const Color(0xFF4B6BFB),
          label: 'Est. duration',
          value: formatDuration(job.estimatedDurationS!),
        ),
      if (job.estimatedCost != null)
        _DetailRow(
          icon: Icons.attach_money_rounded,
          iconBg: const Color(0x1F34C759),
          iconColor: const Color(0xFF34C759),
          label: 'Est. cost',
          value: '${job.estimatedCost!.toStringAsFixed(2)} TND',
          valueColor: const Color(0xFF34C759),
        ),
    ];

    return Container(
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
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(height: 0.5, indent: 60, color: Color(0x1A3C3C43)),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, color: Color(0xFF333333))),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Job job;
  final String Function(DateTime?) formatTime;
  final bool isCompleted;

  const _TimelineCard({
    required this.job,
    required this.formatTime,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(label: 'Submitted', time: formatTime(job.submittedAt),
          done: true),
      _TimelineStep(label: 'Scheduled', time: formatTime(job.scheduledAt),
          done: job.scheduledAt != null),
      _TimelineStep(label: 'Started', time: formatTime(job.startedAt),
          done: job.startedAt != null, isActive: true),
      _TimelineStep(label: 'Completed', time: formatTime(job.endedAt),
          done: isCompleted, isLast: true),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
          BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: steps,
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final String time;
  final bool done;
  final bool isActive;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.time,
    required this.done,
    this.isActive = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = done
        ? (isActive ? const Color(0xFFFF9500) : const Color(0xFF4B6BFB))
        : const Color(0x1A3C3C43);
    final lineColor =
        done ? const Color(0x334B6BFB) : const Color(0x1A3C3C43);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration:
                  BoxDecoration(color: dotColor.withValues(alpha: done ? (isActive ? 1.0 : 0.12) : 0.06),
                      shape: BoxShape.circle),
              child: Icon(
                isActive && done
                    ? Icons.play_arrow_rounded
                    : done
                        ? Icons.check_rounded
                        : Icons.circle_outlined,
                color: done ? (isActive ? Colors.white : const Color(0xFF4B6BFB)) : const Color(0x1A3C3C43),
                size: 16,
              ),
            ),
            if (!isLast)
              Container(
                  width: 1.5,
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            done ? FontWeight.w600 : FontWeight.w400,
                        color:
                            done ? Colors.black : const Color(0xFF8E8E93))),
                Text(time,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF8E8E93))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0x14FF3B30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x26FF3B30)),
        ),
        child: const Center(
          child: Text('Cancel Job',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF3B30))),
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final String jobId;
  final bool loading;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _ConfirmSheet({
    required this.jobId,
    required this.loading,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: const Color(0x66000000),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0x1A3C3C43),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text('Cancel Job #${jobId.substring(0, 8).toUpperCase()}?',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'The print will stop immediately.\nThis cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      height: 1.55),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Yes, Cancel',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4B6BFB),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Keep Printing',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
