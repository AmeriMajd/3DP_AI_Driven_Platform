import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';
import 'status_pill.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final bool live;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.sub,
    this.live = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: DT.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (live) ...[const SizedBox(width: 8), const LiveBadge()],
          if (sub != null) ...[
            const SizedBox(width: 8),
            // ignore: use_null_aware_elements
            Text(sub!, style: const TextStyle(color: DT.text3, fontSize: 12)),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class DashCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const DashCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: DT.surface1,
        border: Border.all(color: DT.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
