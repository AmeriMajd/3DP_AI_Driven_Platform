import 'package:flutter/material.dart';
import '../../domain/stl_file.dart';

class GeometryInfoCard extends StatelessWidget {
  final STLFile file;
  const GeometryInfoCard({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Model information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Dimensions label ─────────────────────────────────────────
            Text(
              'Dimensions (mm)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),

            // ── Dimension Pills ──────────────────────────────────────────
            Row(
              children: [
                _DimensionPill(axis: 'X', value: file.bboxXMm, colorScheme: colorScheme),
                const SizedBox(width: 10),
                _DimensionPill(axis: 'Y', value: file.bboxYMm, colorScheme: colorScheme),
                const SizedBox(width: 10),
                _DimensionPill(axis: 'Z', value: file.bboxZMm, colorScheme: colorScheme),
              ],
            ),

            const SizedBox(height: 16),
            Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              height: 1,
            ),
            const SizedBox(height: 16),

            // ── Volume + Triangles ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Volume',
                    value: file.volumeCm3 != null
                        ? '${_formatVolume(file.volumeCm3!)} mm³'
                        : '---',
                    colorScheme: colorScheme,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Triangles',
                    value: file.triangleCount != null
                        ? _formatNumber(file.triangleCount!)
                        : '---',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),

            // ── File Size + Surface Area ──────────────────────────────────
            // if (file.fileSizeBytes > 0) ...[
            //   const SizedBox(height: 12),
            //   Divider(
            //     color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            //     height: 1,
            //   ),
            //   const SizedBox(height: 12),
            //   Row(
            //     children: [
            //       Expanded(
            //         child: _StatItem(
            //           label: 'File size',
            //           value: file.formattedSize,
            //           colorScheme: colorScheme,
            //         ),
            //       ),
            //       if (file.surfaceAreaCm2 != null)
            //         Expanded(
            //           child: _StatItem(
            //             label: 'Surface area',
            //             value: '${file.surfaceAreaCm2!.toStringAsFixed(1)} cm²',
            //             colorScheme: colorScheme,
            //           ),
            //         ),
            //     ],
            //   ),
            // ],

            // ── Warnings ─────────────────────────────────────────────────
            if (file.isReady) ...[
              if (file.hasOverhangs == 'yes') ...[
                const SizedBox(height: 14),
                const _WarningBanner(
                  message:
                      'Overhangs detected — support structures will be needed. '
                      'This affects print time and material cost.',
                ),
              ],
              if (file.hasThinWalls == 'yes') ...[
                const SizedBox(height: 8),
                const _WarningBanner(
                  message:
                      'Thin walls detected — some areas may not print correctly. '
                      'Consider using a finer layer height.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatVolume(double cm3) {
    final mm3 = (cm3 * 1000).round();
    final s = mm3.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202F');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202F');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Dimension Pill ────────────────────────────────────────────────────────────

class _DimensionPill extends StatelessWidget {
  final String axis;
  final double? value;
  final ColorScheme colorScheme;

  const _DimensionPill({
    required this.axis,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          // surfaceContainerHighest s'adapte automatiquement light/dark
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              axis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPlaceholder
                  ? '---'
                  : value! % 1 == 0
                      ? value!.toInt().toString()
                      : value!.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isPlaceholder
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;

  const _StatItem({
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == '---';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isPlaceholder
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                    : colorScheme.onSurface,
              ),
        ),
      ],
    );
  }
}

// ── Warning Banner ────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    // Couleurs fixes — le orange warning ne dépend pas du thème
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A4500),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}