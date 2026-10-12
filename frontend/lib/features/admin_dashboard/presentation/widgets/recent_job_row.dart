import 'package:flutter/material.dart';

import '../../domain/admin_dashboard_models.dart';
import 'avatar.dart';
import 'dashboard_tokens.dart';
import 'status_pill.dart';

class RecentJobRow extends StatelessWidget {
  final RecentJobItem job;
  final bool last;
  final VoidCallback? onTap;

  const RecentJobRow({super.key, required this.job, this.last = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: DT.divider, width: 1)),
        ),
        child: Row(
          children: [
            DashAvatar(name: job.userName, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          job.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DT.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(status: job.status, dense: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '#${job.id.substring(0, job.id.length < 6 ? job.id.length : 6)}',
                        style: const TextStyle(
                          color: DT.text3,
                          fontSize: 11,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(color: DT.text3, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          job.printerName ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: DT.text3, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  job.estimatedCost == null ? '—' : formatMoney(job.estimatedCost!),
                  style: const TextStyle(
                    color: DT.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo(job.submittedAt),
                  style: const TextStyle(color: DT.text3, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
