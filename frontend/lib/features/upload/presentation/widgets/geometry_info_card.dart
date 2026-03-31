import 'package:flutter/material.dart';
import '../../domain/stl_file.dart';

class GeometryInfoCard extends StatelessWidget {
  final STLFile file;
  const GeometryInfoCard({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.view_in_ar_rounded,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Geometry',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Grid 2x3
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _InfoTile(
                  label: 'Dimension X',
                  value: file.bboxXMm != null
                      ? '${file.bboxXMm!.toStringAsFixed(1)} mm'
                      : '---',
                ),
                _InfoTile(
                  label: 'Dimension Y',
                  value: file.bboxYMm != null
                      ? '${file.bboxYMm!.toStringAsFixed(1)} mm'
                      : '---',
                ),
                _InfoTile(
                  label: 'Dimension Z',
                  value: file.bboxZMm != null
                      ? '${file.bboxZMm!.toStringAsFixed(1)} mm'
                      : '---',
                ),
                _InfoTile(
                  label: 'Volume',
                  value: file.volumeCm3 != null
                      ? '${(file.volumeCm3! * 1000).toStringAsFixed(0)} mm³'
                      : '---',
                ),
                _InfoTile(
                  label: 'Triangles',
                  value: file.triangleCount != null
                      ? _formatNumber(file.triangleCount!)
                      : '---',
                ),
                _InfoTile(label: 'File Size', value: file.formattedSize),
              ],
            ),

            // Warnings — affichés seulement si status = ready
            if (file.isReady) ...[
              if (file.hasOverhangs == 'yes')
                _WarningBanner(
                  'Overhangs detected — support structures will be needed. '
                  'This affects print time and material cost.',
                ),
              if (file.hasThinWalls == 'yes')
                _WarningBanner(
                  'Thin walls detected — some areas may not print correctly. '
                  'Consider using a finer layer height.',
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

// ── Info Tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == '---';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isPlaceholder
                  ? const Color(0xFFD1D1D6)
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Warning Banner ────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.orange.withValues(alpha: 0.10),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.40)),
      borderRadius: BorderRadius.circular(8),
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
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
