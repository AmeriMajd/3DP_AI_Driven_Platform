import 'package:flutter/material.dart';
import '../../domain/job.dart';

class JobStatusBadge extends StatelessWidget {
  final String status;
  const JobStatusBadge({super.key, required this.status});

  static const _config = {
    Job.queued:    _BadgeConfig('#8E8E93', 'rgba(142,142,147,0.14)', '#636366', 'Queued'),
    Job.scheduled: _BadgeConfig('#4B6BFB', 'rgba(75,107,251,0.12)',  '#2E4FD4', 'Scheduled'),
    Job.printing:  _BadgeConfig('#FF9500', 'rgba(255,149,0,0.13)',   '#C97000', 'Printing'),
    Job.completed: _BadgeConfig('#34C759', 'rgba(52,199,89,0.12)',   '#1E7A38', 'Completed'),
    Job.paused:    _BadgeConfig('#FFCC00', 'rgba(255,204,0,0.14)',   '#9A7600', 'Paused'),
    Job.failed:    _BadgeConfig('#FF3B30', 'rgba(255,59,48,0.10)',   '#C0392B', 'Failed'),
    Job.canceled:  _BadgeConfig('#FF3B30', 'rgba(255,59,48,0.10)',   '#C0392B', 'Cancelled'),
  };

  Color _hex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config[status] ??
        const _BadgeConfig('#8E8E93', 'rgba(142,142,147,0.14)', '#636366', 'Unknown');

    final dotColor = _hex(cfg.dot);
    final textColor = _hex(cfg.text);
    final bgColor = _parseBg(cfg.bg);
    final isPrinting = status == Job.printing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 9,
            height: 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isPrinting)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.9),
                    duration: const Duration(milliseconds: 1400),
                    builder: (_, v, _) => Transform.scale(
                      scale: v,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor.withValues(alpha: (1.9 - v) / 0.9 * 0.5),
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(cfg.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
        ],
      ),
    );
  }

  Color _parseBg(String rgba) {
    // Parse rgba(r,g,b,a) format
    final match = RegExp(r'rgba\((\d+),(\d+),(\d+),([\d.]+)\)').firstMatch(rgba);
    if (match != null) {
      final r = int.parse(match.group(1)!);
      final g = int.parse(match.group(2)!);
      final b = int.parse(match.group(3)!);
      final a = double.parse(match.group(4)!);
      return Color.fromRGBO(r, g, b, a);
    }
    return Colors.transparent;
  }
}

class _BadgeConfig {
  final String dot;
  final String bg;
  final String text;
  final String label;
  const _BadgeConfig(this.dot, this.bg, this.text, this.label);
}
