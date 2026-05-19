import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String sub;
  final double delta;
  final IconData icon;
  final Color accent;
  final bool loading;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.sub,
    required this.delta,
    required this.icon,
    required this.accent,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _KpiSkeleton();
    final up = delta >= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: DT.text3,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: DT.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: const TextStyle(
                      color: DT.text3,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 10,
                color: up ? DT.up : DT.down,
              ),
              const SizedBox(width: 2),
              Text(
                '${delta.abs().toStringAsFixed(delta.abs() < 10 ? 1 : 0)}%',
                style: TextStyle(
                  color: up ? DT.up : DT.down,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DT.text3, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiSkeleton extends StatefulWidget {
  const _KpiSkeleton();
  @override
  State<_KpiSkeleton> createState() => _KpiSkeletonState();
}

class _KpiSkeletonState extends State<_KpiSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _bar({double width = 60, double height = 12}) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: const [DT.surface2, DT.surface3, DT.surface2],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.surface1,
        border: Border.all(color: DT.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_bar(width: 80), _bar(width: 26, height: 26)],
          ),
          const SizedBox(height: 14),
          _bar(width: 96, height: 24),
          const SizedBox(height: 8),
          _bar(width: 70, height: 10),
        ],
      ),
    );
  }
}
