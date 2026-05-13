import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../jobs/domain/job.dart';
import '../../domain/printer.dart';
import '../../providers/printer_job_providers.dart';
import 'printer_status_badge.dart';

class PrinterCard extends ConsumerWidget {
  final Printer printer;
  final VoidCallback? onTap;

  const PrinterCard({super.key, required this.printer, this.onTap});

  IconData _technologyIcon() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return Icons.layers_outlined;
      case PrinterTechnology.sla:
        return Icons.opacity_outlined;
    }
  }

  Color _iconTileColor() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return const Color(0xFFD1FAE5); // mint
      case PrinterTechnology.sla:
        return const Color(0xFFEDE9FE); // lavender
    }
  }

  Color _iconColor() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return const Color(0xFF059669);
      case PrinterTechnology.sla:
        return AppColors.primary;
    }
  }

  String _technologyLabel() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return 'FDM';
      case PrinterTechnology.sla:
        return 'SLA';
    }
  }

  String _volumeLabel() {
    final x = printer.buildVolumeX;
    final y = printer.buildVolumeY;
    final z = printer.buildVolumeZ;
    if (x == null || y == null || z == null) return '—';
    return '${x.toStringAsFixed(0)}×${y.toStringAsFixed(0)}×${z.toStringAsFixed(0)}';
  }

  String _formatEta(Job job) {
    int? secs = job.timeLeftSeconds;
    if (secs == null &&
        job.estimatedDurationS != null &&
        job.startedAt != null) {
      final elapsed = DateTime.now().difference(job.startedAt!).inSeconds;
      secs = job.estimatedDurationS! - elapsed;
    }
    if (secs == null || secs <= 0) return '—';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(printerActiveJobProvider(printer.id));

    return Material(
      color: AppColors.cardLight,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _iconTileColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_technologyIcon(), color: _iconColor(), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_technologyLabel()} · ${printer.model ?? _technologyLabel()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PrinterStatusBadge(status: printer.status, compact: true),
                ],
              ),
              const SizedBox(height: 14),
              if (job != null) _buildJobBlock(job) else _buildIdleBlock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobBlock(Job job) {
    final pct = job.progressPct.clamp(0, 100).toDouble();
    return Column(
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'In progress',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              _formatEta(job),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdleBlock() {
    return Row(
      children: [
        Expanded(
          child: Text(
            printer.status == PrinterStatusValue.idle
                ? 'Ready'
                : printer.status == PrinterStatusValue.offline
                    ? 'Offline'
                    : printer.status == PrinterStatusValue.error
                        ? 'Needs attention'
                        : 'Maintenance',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          _volumeLabel(),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
