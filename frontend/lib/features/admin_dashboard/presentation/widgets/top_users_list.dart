import 'package:flutter/material.dart';

import '../../domain/admin_dashboard_models.dart';
import 'avatar.dart';
import 'dashboard_tokens.dart';

class TopUsersList extends StatelessWidget {
  final List<TopUserItem> users;
  const TopUsersList({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No spend in range', style: TextStyle(color: DT.text3, fontSize: 12)),
      );
    }
    final maxCost = users.map((u) => u.totalCost).fold<double>(0, (a, b) => a > b ? a : b);
    final maxSafe = maxCost <= 0 ? 1.0 : maxCost;
    return Column(
      children: [
        for (int i = 0; i < users.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TopUserRow(rank: i + 1, user: users[i], maxCost: maxSafe),
        ],
      ],
    );
  }
}

class _TopUserRow extends StatelessWidget {
  final int rank;
  final TopUserItem user;
  final double maxCost;
  const _TopUserRow({required this.rank, required this.user, required this.maxCost});

  @override
  Widget build(BuildContext context) {
    final top = rank == 1;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: top ? DT.accentSoft : DT.surface2,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              color: top ? DT.accent : DT.text3,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        DashAvatar(name: user.fullName, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: DT.text, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 4,
                        color: DT.surface3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (user.totalCost / maxCost).clamp(0.0, 1.0),
                            child: Container(color: DT.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${user.jobsCount} jobs',
                    style: const TextStyle(color: DT.text3, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMoney(user.totalCost),
          style: const TextStyle(
            color: DT.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
