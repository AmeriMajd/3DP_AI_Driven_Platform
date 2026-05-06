import 'package:flutter/material.dart';

class EstimateCard extends StatelessWidget {
  final double? cost;
  final int? minutes;
  final String? currency;
  final String? confidence;
  final bool isAlt;
  final double? primaryCost;
  final int? primaryMinutes;

  const EstimateCard({
    super.key,
    this.cost,
    this.minutes,
    this.currency,
    this.confidence,
    this.isAlt = false,
    this.primaryCost,
    this.primaryMinutes,
  });

  static String formatCost(double? value, String? currency) {
    if (value == null) return '—';
    final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$formatted ${currency ?? 'TND'}';
  }

  static String formatTime(int? minutes) {
    if (minutes == null) return '—';
    if (minutes < 60) return '$minutes min';
    if (minutes < 600) {
      final h = minutes ~/ 60;
      final m = ((minutes % 60) / 5).round() * 5;
      if (m == 60) return '${h + 1}h';
      if (m == 0) return '${h}h';
      return '${h}h ${m}min';
    }
    if (minutes < 1440) return '~${(minutes / 60).round()}h';
    final days = minutes ~/ 1440;
    final remH = ((minutes % 1440) / 60).round();
    if (remH == 0) return '~${days}d';
    return '~${days}d ${remH}h';
  }

  String? _costDeltaText() {
    if (primaryCost == null || cost == null) return null;
    final d = cost! - primaryCost!;
    if (d.abs() < 0.01) return null;
    final sign = d > 0 ? '+' : '−';
    return '$sign${d.abs().toStringAsFixed(2).replaceAll('.', ',')} ${currency ?? 'TND'} vs primary';
  }

  String? _timeDeltaText() {
    if (primaryMinutes == null || minutes == null) return null;
    final d = minutes! - primaryMinutes!;
    if (d == 0) return null;
    final sign = d > 0 ? '+' : '−';
    return '$sign${formatTime(d.abs())} vs primary';
  }

  @override
  Widget build(BuildContext context) {
    final isLow = (confidence ?? 'high') == 'low';
    final costDelta = _costDeltaText();
    final timeDelta = _timeDeltaText();
    final costDeltaPositive =
        primaryCost != null && cost != null ? cost! > primaryCost! : null;
    final timeDeltaPositive =
        primaryMinutes != null && minutes != null
            ? minutes! > primaryMinutes!
            : null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Estimated Cost & Time',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B6B77),
                    letterSpacing: 0.10,
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: Color(0xFFA05C00)),
                ],
                const Spacer(),
                if (isAlt)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF0FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ALT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E45C4),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _EstimateValueTile(
                      icon: Icons.attach_money_rounded,
                      iconBg: const Color(0xFFE8F5EE),
                      iconColor: const Color(0xFF0F7A45),
                      accentColor: const Color(0xFF16A35C),
                      value: formatCost(cost, currency),
                      label: 'TOTAL COST',
                      deltaText: costDelta,
                      deltaPositive: costDeltaPositive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EstimateValueTile(
                      icon: Icons.schedule_rounded,
                      iconBg: const Color(0xFFECF0FD),
                      iconColor: const Color(0xFF3451D1),
                      accentColor: const Color(0xFF3451D1),
                      value: formatTime(minutes),
                      label: 'PRINT TIME',
                      deltaText: timeDelta,
                      deltaPositive: timeDeltaPositive,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
                height: 28, thickness: 1, color: Color(0x0E000000)),
            Text(
              isLow
                  ? 'Rough estimate — accuracy reduced for this part.'
                  : 'Approximate — ±25% vs slicer output.',
              style: TextStyle(
                fontSize: 11.5,
                color: isLow
                    ? const Color(0xFFA05C00)
                    : const Color(0xFFA8A8B3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateValueTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color accentColor;
  final String value;
  final String label;
  final String? deltaText;
  final bool? deltaPositive;

  const _EstimateValueTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.accentColor,
    required this.value,
    required this.label,
    this.deltaText,
    this.deltaPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C0C10),
                  letterSpacing: -0.4,
                ),
              ),
              if (deltaText != null && deltaPositive != null)
                _DeltaPill(text: deltaText!, positive: deltaPositive!),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA8A8B3),
                  letterSpacing: 0.08,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 14,
          right: 14,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeltaPill extends StatelessWidget {
  final String text;
  final bool positive; // true = higher than primary → red

  const _DeltaPill({required this.text, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color =
        positive ? const Color(0xFFC1320C) : const Color(0xFF0F7A45);
    final bg =
        positive ? const Color(0xFFFEF0EC) : const Color(0xFFE8F5EE);
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.05,
        ),
      ),
    );
  }
}
