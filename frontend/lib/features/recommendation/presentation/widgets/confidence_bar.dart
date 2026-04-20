import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Coloured linear progress bar with confidence percentage label.
/// Tier thresholds: high ≥ 0.75 (green), medium ≥ 0.50 (amber), low < 0.50 (red).
class ConfidenceBar extends StatelessWidget {
  final double confidence; // 0.0–1.0
  final String? label;

  const ConfidenceBar({super.key, required this.confidence, this.label});

  Color get _tierColor {
    if (confidence >= 0.75) return AppColors.success;
    if (confidence >= 0.50) return AppColors.warning;
    return AppColors.error;
  }

  String get _tierLabel {
    if (confidence >= 0.75) return 'High';
    if (confidence >= 0.50) return 'Medium';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? 'Confidence',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _tierLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _tierColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _tierColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(_tierColor),
          ),
        ),
      ],
    );
  }
}
