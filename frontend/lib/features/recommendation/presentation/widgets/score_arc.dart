import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Arc gauge widget (240° sweep, 7-o'clock start) for a 0–100 score.
class ScoreArc extends StatelessWidget {
  final String label;
  final int score; // 0–100
  final double size;

  const ScoreArc({
    super.key,
    required this.label,
    required this.score,
    this.size = 90,
  });

  Color get _scoreColor {
    if (score >= 80) return AppColors.success;
    if (score >= 50) return AppColors.warning;
    if (score >= 25) return const Color(0xFFF97316); // orange
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ArcPainter(
              score: score,
              foregroundColor: _scoreColor,
              backgroundColor: AppColors.borderLight,
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final int score;
  final Color foregroundColor;
  final Color backgroundColor;

  static const double _sweepTotal = math.pi * 4 / 3; // 240°
  // Start at 7-o'clock: 150° from positive x-axis = π * 5/6
  static const double _startAngle = math.pi * 5 / 6;

  _ArcPainter({
    required this.score,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.10;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background arc (full 240°)
    canvas.drawArc(rect, _startAngle, _sweepTotal, false, bgPaint);

    // Foreground arc (score fraction of 240°)
    final sweep = _sweepTotal * (score.clamp(0, 100) / 100.0);
    if (sweep > 0) {
      canvas.drawArc(rect, _startAngle, sweep, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.score != score ||
      old.foregroundColor != foregroundColor ||
      old.backgroundColor != backgroundColor;
}
