import 'package:flutter/material.dart';

import '../../domain/admin_dashboard_models.dart';
import 'dashboard_tokens.dart';

class ActiveJobCard extends StatelessWidget {
  final ActiveJobItem job;
  const ActiveJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final c = StatusColors.of('printing');
    final pct = job.progressPct.clamp(0, 100).toDouble();
    final remaining = job.timeLeftSeconds ??
        (job.estimatedDurationS == null
            ? null
            : (job.estimatedDurationS! * (1 - pct / 100)).round());
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.surface1,
        border: Border.all(color: DT.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: DT.surface3,
                  border: Border.all(color: DT.border),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.precision_manufacturing_rounded, size: 18, color: c.fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${job.id.substring(0, job.id.length < 6 ? job.id.length : 6)}',
                          style: const TextStyle(
                            color: DT.text3,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: DT.text3, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            job.printerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: DT.text3, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.file ?? job.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: DT.text, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      job.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: DT.text2, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBar(pct: pct),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: DT.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                remaining == null ? '—' : '${formatDuration(remaining)} left',
                style: const TextStyle(
                  color: DT.text3,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double pct;
  const _ProgressBar({required this.pct});
  @override
  Widget build(BuildContext context) {
    final c = StatusColors.of('printing');
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: DT.surface3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (pct / 100).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.fg, Color.lerp(c.fg, Colors.white, 0.3)!],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
