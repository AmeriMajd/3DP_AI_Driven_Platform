import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';

class StatusPill extends StatelessWidget {
  final String status;
  final bool dense;
  const StatusPill({super.key, required this.status, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = StatusColors.of(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: c.fg, animate: status == 'printing'),
          const SizedBox(width: 5),
          Text(
            statusLabel(status),
            style: TextStyle(
              color: c.fg,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulseDot({required this.color, required this.animate});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(3)),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.55 + 0.45 * (1 - t)),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final c = StatusColors.of('printing');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: c.fg, animate: true),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
              color: c.fg,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
