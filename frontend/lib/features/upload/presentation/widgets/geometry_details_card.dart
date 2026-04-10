import 'package:flutter/material.dart';
import '../../domain/stl_file.dart';

class GeometryDetailsCard extends StatelessWidget {
  final STLFile file;
  const GeometryDetailsCard({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section 1 : Dimensions ──
        _SectionCard(
          title: 'Dimensions',
          icon: Icons.straighten_outlined,
          children: [
            // Bounding box — 3 pills compactes sur une ligne avec unité intégrée
            _BBoxRow(file: file),
            const SizedBox(height: 12),
            // Volume + Surface Area sur une ligne
            _InlineStatRow(children: [
              _InlineStat(
                label: 'Volume',
                value: file.volumeCm3 != null
                    ? '${file.volumeCm3!.toStringAsFixed(1)} cm³'
                    : '—',
              ),
              _InlineStat(
                label: 'Surface Area',
                value: file.surfaceAreaCm2 != null
                    ? '${file.surfaceAreaCm2!.toStringAsFixed(1)} cm²'
                    : '—',
              ),
            ]),
            const SizedBox(height: 8),
            // Flat Base + Aspect Ratio sur une ligne
            _InlineStatRow(children: [
              _InlineStat(
                label: 'Flat Base Area',
                value: file.flatBaseAreaMm2 != null
                    ? '${file.flatBaseAreaMm2!.toStringAsFixed(0)} mm²'
                    : '—',
              ),
              _InlineStat(
                label: 'Aspect Ratio',
                value: file.aspectRatio != null
                    ? file.aspectRatio!.toStringAsFixed(2)
                    : '—',
                warning: (file.aspectRatio ?? 0) > 5,
                warningText: '> 5 — prone to warping',
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 2 : Mesh Quality ──
        _SectionCard(
          title: 'Mesh Quality',
          icon: Icons.view_in_ar_outlined,
          children: [
            // Triangles + Shell Count
            _InlineStatRow(children: [
              _InlineStat(
                label: 'Triangles',
                value: file.triangleCount != null
                    ? _formatNumber(file.triangleCount!)
                    : '—',
              ),
              _InlineStat(
                label: 'Shell Count',
                value: file.shellCount?.toString() ?? '—',
              ),
            ]),
            const SizedBox(height: 8),
            // Watertight + Complexity Index
            _InlineStatRow(children: [
              _WatertightInline(isWatertight: file.isWatertight),
              _InlineStat(
                label: 'Complexity Index',
                value: file.complexityIndex != null
                    ? file.complexityIndex!.toStringAsFixed(2)
                    : '—',
                hint: 'Surface area / volume ratio',
              ),
            ]),
            // CoM Offset — uniquement si présent, déprioritisé (texte petit)
            if (file.comOffsetRatio != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.center_focus_weak_outlined,
                      size: 12, color: Color(0xFFAEAEB2)),
                  const SizedBox(width: 5),
                  Text(
                    'Center of mass offset: ${file.comOffsetRatio!.toStringAsFixed(3)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFAEAEB2)),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Section 3 : Printability ──
        _SectionCard(
          title: 'Printability',
          icon: Icons.print_outlined,
          children: [
            _OverhangRatioBar(ratio: file.overhangRatio),
            const SizedBox(height: 12),
            // Max Overhang Angle + Min Wall Thickness
            _InlineStatRow(children: [
              _InlineStat(
                label: 'Max Overhang Angle',
                value: file.maxOverhangAngle != null
                    ? '${file.maxOverhangAngle!.toStringAsFixed(1)}°'
                    : '—',
              ),
              _InlineStat(
                label: 'Min Wall Thickness',
                value: file.minWallThicknessMm != null
                    ? '${file.minWallThicknessMm!.toStringAsFixed(2)} mm'
                    : '—',
                warning: (file.minWallThicknessMm ?? 99) < 0.8,
                warningText: '< 0.8 mm — may not print',
              ),
            ]),
            const SizedBox(height: 8),
            // Avg Wall Thickness — même ligne avec un spacer pour équilibrer
            _InlineStatRow(children: [
              _InlineStat(
                label: 'Avg Wall Thickness',
                value: file.avgWallThicknessMm != null
                    ? '${file.avgWallThicknessMm!.toStringAsFixed(2)} mm'
                    : '—',
              ),
              const _EmptyStat(),
            ]),
          ],
        ),
      ],
    );
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

// ── Section Card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── BBox Row — X / Y / Z avec unité dans la pill ────────────────────────────
class _BBoxRow extends StatelessWidget {
  final STLFile file;
  const _BBoxRow({required this.file});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AxisPill(axis: 'X', value: file.bboxXMm),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('×',
              style: TextStyle(
                  color: Color(0xFFAEAEB2),
                  fontSize: 13,
                  fontWeight: FontWeight.w300)),
        ),
        _AxisPill(axis: 'Y', value: file.bboxYMm),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('×',
              style: TextStyle(
                  color: Color(0xFFAEAEB2),
                  fontSize: 13,
                  fontWeight: FontWeight.w300)),
        ),
        _AxisPill(axis: 'Z', value: file.bboxZMm),
        const SizedBox(width: 8),
        const Text('mm',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFFAEAEB2),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AxisPill extends StatelessWidget {
  final String axis;
  final double? value;
  const _AxisPill({required this.axis, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            axis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value != null
                ? (value! % 1 == 0
                    ? value!.toInt().toString()
                    : value!.toStringAsFixed(1))
                : '—',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inline Stat Row — deux stats côte à côte sans background tile ─────────────
class _InlineStatRow extends StatelessWidget {
  final List<Widget> children;
  const _InlineStatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children
            .expand((w) sync* {
              yield Expanded(child: w);
              if (w != children.last) yield const SizedBox(width: 8);
            })
            .toList(),
      ),
    );
  }
}

// ── Inline Stat — compact, fond gris léger ────────────────────────────────────
class _InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warning;
  final String? warningText;
  final String? hint;

  const _InlineStat({
    required this.label,
    required this.value,
    this.warning = false,
    this.warningText,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF3E0) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(10),
        border: warning
            ? Border.all(color: Colors.orange.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: warning
                  ? const Color(0xFF7A4500)
                  : const Color(0xFF1C1C1E),
            ),
          ),
          if (warning && warningText != null) ...[
            const SizedBox(height: 2),
            Text(warningText!,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF7A4500))),
          ],
          if (!warning && hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFAEAEB2))),
          ],
        ],
      ),
    );
  }
}

// Placeholder transparent pour équilibrer une ligne avec un seul stat
class _EmptyStat extends StatelessWidget {
  const _EmptyStat();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Watertight inline — même style que _InlineStat ────────────────────────────
class _WatertightInline extends StatelessWidget {
  final bool? isWatertight;
  const _WatertightInline({required this.isWatertight});

  @override
  Widget build(BuildContext context) {
    if (isWatertight == null) {
      return const _InlineStat(label: 'Watertight', value: '—');
    }
    final ok = isWatertight!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFEBFBF0) : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? const Color(0xFF22C55E).withValues(alpha: 0.35)
              : const Color(0xFFEF4444).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Watertight',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF8E8E93))),
              const SizedBox(height: 2),
              Text(
                ok ? 'Yes' : 'No',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ok
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overhang Ratio Bar ────────────────────────────────────────────────────────
class _OverhangRatioBar extends StatelessWidget {
  final double? ratio;
  const _OverhangRatioBar({required this.ratio});

  Color get _levelColor {
    if (ratio == null) return const Color(0xFF8E8E93);
    if (ratio! < 0.2) return const Color(0xFF22C55E);
    if (ratio! <= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _levelLabel {
    if (ratio == null) return '—';
    if (ratio! < 0.2) return 'Low — supports likely not needed';
    if (ratio! <= 0.5) return 'Medium — supports recommended';
    return 'High — supports required';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (ratio ?? 0.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + valeur
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overhang Ratio',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E)),
            ),
            Text(
              ratio != null ? '${(pct * 100).toStringAsFixed(1)}%' : '—',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _levelColor),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Gradient bar avec curseur
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                // Gradient fond
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF22C55E),
                        Color(0xFFF59E0B),
                        Color(0xFFEF4444),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                // Overlay blanc pour la partie non atteinte
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 1.0 - pct,
                    child: Container(
                        color: Colors.white.withValues(alpha: 0.72)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Niveau + légende dots sur la même ligne
        Row(
          children: [
            Text(
              _levelLabel,
              style: TextStyle(
                  fontSize: 11,
                  color: _levelColor,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            _LegendDot(color: const Color(0xFF22C55E), label: '< 20%'),
            const SizedBox(width: 8),
            _LegendDot(color: const Color(0xFFF59E0B), label: '20–50%'),
            const SizedBox(width: 8),
            _LegendDot(color: const Color(0xFFEF4444), label: '> 50%'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: Color(0xFFAEAEB2))),
      ],
    );
  }
}