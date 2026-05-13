import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_wrapper.dart';
import '../../../jobs/domain/job.dart';
import '../../../jobs/presentation/providers/job_providers.dart';
import '../../domain/printer.dart';
import '../../providers/printer_job_providers.dart';
import '../../providers/printer_providers.dart';

class PrinterDetailScreen extends ConsumerWidget {
  final String printerId;

  const PrinterDetailScreen({super.key, required this.printerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerAsync = ref.watch(printerDetailProvider(printerId));
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _circleIconBtn(
            Icons.arrow_back_ios_new_rounded,
            () => context.pop(),
          ),
        ),
        title: const Text(
          'Printer details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _circleIconBtn(
                Icons.edit_outlined,
                () => context.go('${AppRoutes.fleet}/$printerId/edit'),
              ),
            ),
        ],
      ),
      body: printerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (printer) => _Body(printer: printer, isAdmin: isAdmin),
      ),
    );
  }

  static Widget _circleIconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.cardLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Printer printer;
  final bool isAdmin;

  const _Body({required this.printer, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(printerActiveJobProvider(printer.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: ResponsiveWrapper(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MainCard(printer: printer, job: job),
            if (job != null) ...[
              const SizedBox(height: 14),
              _ActionRow(job: job),
            ],
            const SizedBox(height: 20),
            const _SectionTitle('LIVE METRICS'),
            const SizedBox(height: 10),
            _MetricsGrid(job: job),
            const SizedBox(height: 20),
            const _SectionTitle('SPECIFICATIONS'),
            const SizedBox(height: 10),
            _SpecsCard(printer: printer),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _AdminActions(printer: printer),
            ],
          ],
        ),
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final Printer printer;
  final Job? job;
  const _MainCard({required this.printer, this.job});

  String _techLabel() => printer.technology == PrinterTechnology.fdm
      ? 'FDM'
      : 'SLA';

  String _formatElapsed(Job j) {
    if (j.startedAt == null) return '—';
    final d = DateTime.now().difference(j.startedAt!);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(Job j) {
    int? secs = j.timeLeftSeconds;
    if (secs == null &&
        j.estimatedDurationS != null &&
        j.startedAt != null) {
      secs = j.estimatedDurationS! -
          DateTime.now().difference(j.startedAt!).inSeconds;
    }
    if (secs == null || secs <= 0) return '—';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      printer.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_techLabel()} · ${printer.model ?? _techLabel()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (job != null)
                _ProgressRing(
                  pct: job!.progressPct,
                  remaining: _formatRemaining(job!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _CameraPlaceholder(elapsed: job == null ? '--:--:--' : _formatElapsed(job!)),
          if (job != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NOW PRINTING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Text(
                  'L —/—',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              job!.displayName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double pct;
  final String remaining;
  const _ProgressRing({required this.pct, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(84, 84),
            painter: _RingPainter(pct: pct.clamp(0, 100).toDouble()),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  text: pct.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  children: const [
                    TextSpan(
                      text: '%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                remaining,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  _RingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final bg = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      (pct / 100) * 2 * math.pi,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}

class _CameraPlaceholder extends StatelessWidget {
  final String elapsed;
  const _CameraPlaceholder({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(
        painter: _StripesPainter(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE CAMERA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'REC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cardLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 14,
                          color: AppColors.textPrimary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Open stream',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        elapsed,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _StripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.06)
      ..strokeWidth = 8;
    for (double x = -size.height; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ActionRow extends ConsumerWidget {
  final Job job;
  const _ActionRow({required this.job});

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<Job> Function() call,
  ) async {
    try {
      await call();
      ref.invalidate(myJobsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(jobRepositoryProvider);
    final isPaused = job.status == Job.paused;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _act(
              context,
              ref,
              () => isPaused ? repo.resumeJob(job.id) : repo.suspendJob(job.id),
            ),
            icon: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
            label: Text(
              isPaused ? 'Resume print' : 'Pause print',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _squareBtn(
          icon: Icons.stop_rounded,
          color: AppColors.error,
          onTap: () => _act(context, ref, () => repo.cancelJob(job.id)),
        ),
        const SizedBox(width: 8),
        _squareBtn(
          icon: Icons.photo_camera_outlined,
          color: AppColors.textPrimary,
          onTap: () {}, // camera stream not implemented
        ),
      ],
    );
  }

  Widget _squareBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Job? job;
  const _MetricsGrid({this.job});

  String _elapsedLabel() {
    if (job?.startedAt == null) return '—';
    final d = DateTime.now().difference(job!.startedAt!);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _startedLabel() {
    final s = job?.startedAt;
    if (s == null) return '—';
    return 'started ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _MetricTile(
          icon: Icons.thermostat,
          iconBg: const Color(0xFFFEE2E2),
          iconColor: AppColors.error,
          label: 'NOZZLE',
          value: '—',
          subtitle: 'awaiting backend',
        ),
        _MetricTile(
          icon: Icons.thermostat,
          iconBg: const Color(0xFFDBEAFE),
          iconColor: const Color(0xFF2563EB),
          label: 'BED',
          value: '—',
          subtitle: 'awaiting backend',
        ),
        _MetricTile(
          icon: Icons.local_drink_outlined,
          iconBg: const Color(0xFFEDE9FE),
          iconColor: AppColors.primary,
          label: 'FILAMENT',
          value: '—',
          subtitle: 'spool data pending',
        ),
        _MetricTile(
          icon: Icons.schedule_rounded,
          iconBg: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          label: 'ELAPSED',
          value: _elapsedLabel(),
          subtitle: _startedLabel(),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _MetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecsCard extends StatelessWidget {
  final Printer printer;
  const _SpecsCard({required this.printer});

  String _volume() {
    final x = printer.buildVolumeX;
    final y = printer.buildVolumeY;
    final z = printer.buildVolumeZ;
    if (x == null || y == null || z == null) return '—';
    return '${x.toStringAsFixed(0)}×${y.toStringAsFixed(0)}×${z.toStringAsFixed(0)}';
  }

  String _tech() => printer.technology == PrinterTechnology.fdm ? 'FDM' : 'SLA';

  @override
  Widget build(BuildContext context) {
    final materials = printer.materialsSupported ?? const <String>[];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _row('Build volume', Text(_volume(), style: _valueStyle)),
          _divider(),
          _row('Technology', Text(_tech(), style: _valueStyle)),
          _divider(),
          _row(
            'Materials',
            materials.isEmpty
                ? Text('—', style: _valueStyle)
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: materials
                        .map(
                          (m) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              m,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  static const _valueStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6));
}

class _AdminActions extends ConsumerWidget {
  final Printer printer;
  const _AdminActions({required this.printer});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete printer?'),
        content: const Text(
          'This will remove the printer from your fleet. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(printerRepositoryProvider);
      await repo.deletePrinter(id: printer.id);
      ref.invalidate(printersListProvider);
      if (context.mounted) {
        context.go(AppRoutes.fleet);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                context.go('${AppRoutes.fleet}/${printer.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ),
      ],
    );
  }
}
