import 'package:flutter/material.dart';
import '../../domain/stl_file.dart';

/// Affiche les 3 meilleures orientations — toutes en layout compact horizontal.
class OrientationCard extends StatefulWidget {
  final STLFile file;
  final void Function(int index, Map<String, dynamic> orientation)? onSelect;

  const OrientationCard({
    required this.file,
    this.onSelect,
    super.key,
  });

  @override
  State<OrientationCard> createState() => _OrientationCardState();
}

class _OrientationCardState extends State<OrientationCard> {
  int? _selectedIndex;

  void _select(int index, Map<String, dynamic> data) {
    setState(() => _selectedIndex = index);
    widget.onSelect?.call(index, data);
  }

  @override
  Widget build(BuildContext context) {
    final orientations = widget.file.orientations;

    if (orientations.isEmpty) {
      return _buildEmpty();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rotate_90_degrees_cw_outlined,
                  size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The AI computed the top ${orientations.length} print orientations. '
                  'Select one to use in the recommendation.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4338CA),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Toutes les cartes en layout compact ──
        for (int i = 0; i < orientations.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _OrientationTile(
            index: i,
            data: orientations[i],
            isSelected: _selectedIndex == i,
            onSelect: () => _select(i, orientations[i]),
          ),
        ],

        // ── Confirmation sélection ──
        if (_selectedIndex != null) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FFF3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 16, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Orientation ${_selectedIndex! + 1} selected — '
                    'this will be used in your AI recommendation.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF166534)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.rotate_90_degrees_cw_outlined,
              size: 36, color: Color(0xFF8E8E93)),
          SizedBox(height: 10),
          Text('No orientation data yet',
              style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
          SizedBox(height: 4),
          Text(
            'Orientation analysis runs after geometry extraction completes.',
            style: TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Orientation Tile — layout compact horizontal pour toutes les cartes ───────
class _OrientationTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final bool isSelected;
  final VoidCallback onSelect;

  const _OrientationTile({
    required this.index,
    required this.data,
    required this.isSelected,
    required this.onSelect,
  });

  static const _rankColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFCD7F32), // Bronze
  ];
  static const _rankLabels = ['1st', '2nd', '3rd'];

  double get _score => (data['score'] as num?)?.toDouble() ?? 0.0;
  double get _overhangReduction =>
      (data['overhang_reduction_pct'] as num?)?.toDouble() ?? 0.0;
  double get _printHeight =>
      (data['print_height_mm'] as num?)?.toDouble() ?? 0.0;
  double get _rx => (data['rx'] as num?)?.toDouble() ?? 0.0;
  double get _ry => (data['ry'] as num?)?.toDouble() ?? 0.0;
  double get _rz => (data['rz'] as num?)?.toDouble() ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final rankColor = _rankColors[index.clamp(0, 2)];
    final rankLabel = _rankLabels[index.clamp(0, 2)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE5E5EA),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Colonne gauche : rank + score + angles ──
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank badge + check icon
                Row(
                  children: [
                    _RankBadge(label: rankLabel, color: rankColor),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: Color(0xFF6366F1)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Score bar
                _ScoreBar(score: _score),
                const SizedBox(height: 10),

                // Angles Rx / Ry / Rz
                Row(
                  children: [
                    _AnglePill(axis: 'Rx', value: _rx),
                    const SizedBox(width: 4),
                    _AnglePill(axis: 'Ry', value: _ry),
                    const SizedBox(width: 4),
                    _AnglePill(axis: 'Rz', value: _rz),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // ── Colonne droite : stats + bouton ──
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoRow(
                  icon: Icons.arrow_downward_outlined,
                  label: 'Overhang',
                  value: '${_overhangReduction.toStringAsFixed(0)}%',
                  valueColor: _overhangReduction > 20
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF8E8E93),
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.height_outlined,
                  label: 'Height',
                  value: '${_printHeight.toStringAsFixed(1)} mm',
                ),
                const SizedBox(height: 12),

                // Select button
                SizedBox(
                  width: double.infinity,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Container(
                            key: const ValueKey('sel'),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                '✓ Selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            key: const ValueKey('not_sel'),
                            onTap: onSelect,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Center(
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rank Badge ────────────────────────────────────────────────────────────────
class _RankBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RankBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Score Bar ─────────────────────────────────────────────────────────────────
class _ScoreBar extends StatelessWidget {
  final double score;
  const _ScoreBar({required this.score});

  Color get _color {
    if (score >= 0.8) return const Color(0xFF22C55E);
    if (score >= 0.6) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Score',
                style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
            Text(
              '${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: const Color(0xFFF2F2F7),
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
      ],
    );
  }
}

// ── Angle Pill ────────────────────────────────────────────────────────────────
class _AnglePill extends StatelessWidget {
  final String axis;
  final double value;
  const _AnglePill({required this.axis, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          children: [
            Text(axis,
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500)),
            Text(
              value % 1 == 0
                  ? '${value.toInt()}°'
                  : '${value.toStringAsFixed(1)}°',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFF8E8E93)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF8E8E93)),
              overflow: TextOverflow.ellipsis),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1C1C1E)),
        ),
      ],
    );
  }
}