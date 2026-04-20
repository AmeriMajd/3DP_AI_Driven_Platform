// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../../domain/stl_file.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Color palette — single source of truth for the whole upload feature
// ══════════════════════════════════════════════════════════════════════════════
abstract final class AppColors {
  static const primary           = Color(0xFF3F37C9);
  static const accent            = Color(0xFFC7F000);
  static const error             = Color(0xFFD7263D);
  static const surfaceBackground = Color(0xFFF5F5F7);
  static const surfaceContainer  = Color(0xFFECECEF);
  static const outlineVariant    = Color(0xFFE5E5EA);
  static const axisX             = Color(0xFFD7263D);
  static const axisY             = Color(0xFF22C55E);
  static const axisZ             = Color(0xFF3F37C9);
  static const success           = Color(0xFF22C55E);
  static const warning           = Color(0xFFF59E0B);
  static const textPrimary       = Color(0xFF1C1C1E);
  static const textSecondary     = Color(0xFF8E8E93);
  static const textMuted         = Color(0xFFAEAEB2);
}

// ══════════════════════════════════════════════════════════════════════════════
// Tone system — drives MetricCard & QualityFlagCard colouring
// ══════════════════════════════════════════════════════════════════════════════
enum _Tone { neutral, primary, accent, success, danger }

Color _toneIconBg(_Tone t) => switch (t) {
  _Tone.neutral => AppColors.surfaceContainer,
  _Tone.primary => AppColors.primary.withValues(alpha: 0.10),
  _Tone.accent  => AppColors.accent.withValues(alpha: 0.22),
  _Tone.success => AppColors.success.withValues(alpha: 0.12),
  _Tone.danger  => AppColors.error.withValues(alpha: 0.10),
};

Color _toneIconFg(_Tone t) => switch (t) {
  _Tone.neutral => AppColors.textSecondary,
  _Tone.primary => AppColors.primary,
  _Tone.accent  => const Color(0xFF4A5200),
  _Tone.success => AppColors.success,
  _Tone.danger  => AppColors.error,
};

Color _toneCardBg(_Tone t) => switch (t) {
  _Tone.accent  => AppColors.accent.withValues(alpha: 0.06),
  _Tone.success => AppColors.success.withValues(alpha: 0.05),
  _Tone.danger  => AppColors.error.withValues(alpha: 0.08),
  _ => Colors.white,
};

// Returns the hover/press base color that matches each tone.
Color _toneOverlay(_Tone t) => switch (t) {
  _Tone.primary => AppColors.primary,
  _Tone.accent  => AppColors.accent,
  _Tone.success => AppColors.success,
  _Tone.danger  => AppColors.error,
  _Tone.neutral => AppColors.primary,
};

// ══════════════════════════════════════════════════════════════════════════════
// Root widget
// ══════════════════════════════════════════════════════════════════════════════
class GeometryDetailsCard extends StatelessWidget {
  final STLFile file;
  const GeometryDetailsCard({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroBanner(file: file),
        const SizedBox(height: 16),

        _DimensionsCard(file: file),
        const SizedBox(height: 24),

        _SectionHeader(title: 'PHYSICAL PROPERTIES'),
        const SizedBox(height: 12),
        _pair(
          _MetricCard(
            icon: Icons.view_in_ar_rounded,
            label: 'VOLUME',
            value: file.volumeCm3?.toStringAsFixed(1) ?? '--',
            unit: 'cm³',
            tone: _Tone.primary,
            tooltip: 'Total enclosed volume of the mesh. Used to estimate filament/resin usage.',
          ),
          _MetricCard(
            icon: Icons.crop_square_rounded,
            label: 'SURFACE AREA',
            value: file.surfaceAreaCm2?.toStringAsFixed(1) ?? '--',
            unit: 'cm²',
            tone: _Tone.primary,
            tooltip: 'Total area of all triangle faces. Affects print time and surface finishing.',
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          _MetricCard(
            icon: Icons.layers_outlined,
            label: 'FLAT BASE AREA',
            value: file.flatBaseAreaMm2 != null
                ? _fmtInt(file.flatBaseAreaMm2!.toInt())
                : '--',
            unit: 'mm²',
            tone: _Tone.accent,
            tooltip: 'Footprint area of the flattest face. Impacts bed adhesion.',
          ),
          _MetricCard(
            icon: Icons.aspect_ratio_rounded,
            label: 'ASPECT RATIO',
            value: file.aspectRatio?.toStringAsFixed(2) ?? '--',
            hint: file.aspectRatio != null
                ? ((file.aspectRatio! > 4) ? 'Elongated shape' : 'Compact shape')
                : null,
            tone: (file.aspectRatio ?? 0) > 4 ? _Tone.danger : _Tone.neutral,
            tooltip: 'Ratio between the longest and shortest dimensions. High values may need supports or rotation.',
          ),
        ),
        const SizedBox(height: 24),

        _SectionHeader(
          title: 'MESH QUALITY',
          trailing: file.shellCount != null
              ? _ShellChip(count: file.shellCount!)
              : null,
        ),
        const SizedBox(height: 12),
        _pair(
          _MetricCard(
            icon: Icons.change_history_rounded,
            label: 'TRIANGLES',
            value: file.triangleCount != null ? _fmtInt(file.triangleCount!) : '--',
            tone: _Tone.neutral,
            tooltip: 'Total number of mesh triangles. Higher = more detail but heavier file.',
          ),
          _MetricCard(
            icon: Icons.layers_rounded,
            label: 'SHELL COUNT',
            value: file.shellCount?.toString() ?? '--',
            hint: file.shellCount == 1 ? 'Single solid body' : null,
            tone: file.shellCount == 1 ? _Tone.success : _Tone.neutral,
            tooltip: 'Disconnected mesh bodies. 1 = solid, watertight body.',
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          _QualityFlagCard(
            icon: Icons.water_drop_outlined,
            label: 'Watertight',
            statusLabel: file.isWatertight == null
                ? '—'
                : (file.isWatertight! ? 'Yes' : 'No'),
            isNegative: file.isWatertight == false,
            isPositive: file.isWatertight == true,
            tooltip: 'A watertight mesh has no holes or open edges.',
          ),
          _QualityFlagCard(
            icon: Icons.warning_amber_rounded,
            label: 'Overhangs',
            statusLabel: file.hasOverhangs ?? '—',
            isNegative: file.hasOverhangs == 'yes',
            isPositive: file.hasOverhangs == 'no',
            tooltip: 'Faces angled > 45° from vertical may need supports.',
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          _QualityFlagCard(
            icon: Icons.vertical_align_center_rounded,
            label: 'Thin Walls',
            statusLabel: file.hasThinWalls ?? '—',
            isNegative: file.hasThinWalls == 'yes',
            isPositive: file.hasThinWalls == 'no',
            tooltip: 'Walls < 0.8 mm may not print reliably.',
          ),
          _QualityFlagCard(
            icon: Icons.center_focus_strong_rounded,
            label: 'CoM Offset',
            statusLabel: file.comOffsetRatio != null
                ? file.comOffsetRatio!.toStringAsFixed(3)
                : '—',
            isNegative: false,
            isPositive: false,
            isNeutralValue: true,
            tooltip: 'Distance of centre-of-mass from bbox centre. 0 = perfectly balanced.',
          ),
        ),
        const SizedBox(height: 24),

        if (_hasPrintData) ...[
          _PrintabilityCard(file: file),
          const SizedBox(height: 16),
        ],

        const _ReadyForAIPill(),
      ],
    );
  }

  bool get _hasPrintData =>
      file.overhangRatio != null ||
      file.minWallThicknessMm != null ||
      file.complexityIndex != null;
}

// ══════════════════════════════════════════════════════════════════════════════
// Hero Banner
// ══════════════════════════════════════════════════════════════════════════════
class _HeroBanner extends StatelessWidget {
  final STLFile file;
  const _HeroBanner({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30), width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withValues(alpha: 0.95), AppColors.surfaceBackground.withValues(alpha: 0.05),AppColors.primary.withValues(alpha: 0.90)],
          stops: const [0.0, 0.5, 1.0],        
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Faint sparkle icon
          const Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.90,
              child: Icon(Icons.auto_awesome, size: 26, color: AppColors.accent),
            ),
          ),
          // Text content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const _PulsingDot(),
                const SizedBox(width: 7),
                const Text(
                  'ANALYSIS COMPLETE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Geometry extracted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your model has been fully analysed and is ready for AI recommendation.',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween(begin: 0.35, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Bounding Box card
// ══════════════════════════════════════════════════════════════════════════════
class _DimensionsCard extends StatelessWidget {
  final STLFile file;
  const _DimensionsCard({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.straighten_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bounding Box',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    Text('Dimensions in millimeters',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        )),
                  ],
                ),
                const Spacer(),
                Tooltip(
                  message: 'The smallest box that fully contains the model along each axis.',
                  child: const Icon(Icons.info_outline_rounded,
                      size: 17, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // X / Y / Z tiles
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                      child: _AxisTile(
                          axis: 'X',
                          value: file.bboxXMm,
                          color: AppColors.axisX)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _AxisTile(
                          axis: 'Y',
                          value: file.bboxYMm,
                          color: AppColors.axisY)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _AxisTile(
                          axis: 'Z',
                          value: file.bboxZMm,
                          color: AppColors.axisZ)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Summary footer
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.view_in_ar_outlined,
                    size: 13, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  _summary,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _summary {
    final x = file.bboxXMm?.toStringAsFixed(1) ?? '?';
    final y = file.bboxYMm?.toStringAsFixed(1) ?? '?';
    final z = file.bboxZMm?.toStringAsFixed(1) ?? '?';
    return '$x × $y × $z mm';
  }
}

class _AxisTile extends StatelessWidget {
  final String axis;
  final double? value;
  final Color color;
  const _AxisTile({required this.axis, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(axis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text(
            value != null
                ? (value! % 1 == 0
                    ? value!.toInt().toString()
                    : value!.toStringAsFixed(1))
                : '--',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Text('MM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section Header + Shell chip
// ══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            )),
        const Spacer(),
        if (trailing case final w?) w,
      ],
    );
  }
}

class _ShellChip extends StatelessWidget {
  final int count;
  const _ShellChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count shell${count == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MetricCard
// ══════════════════════════════════════════════════════════════════════════════
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? hint;
  final _Tone tone;
  final String? tooltip;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.hint,
    this.tone = _Tone.neutral,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _toneCardBg(tone),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          final c = _toneOverlay(tone);
          if (states.contains(WidgetState.hovered))  return c.withValues(alpha: 0.06);
          if (states.contains(WidgetState.pressed))  return c.withValues(alpha: 0.12);
          return Colors.transparent;
        }),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _toneIconBg(tone),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 18, color: _toneIconFg(tone)),
                  ),
                  const Spacer(),
                  if (tooltip != null)
                    Tooltip(
                      message: tooltip!,
                      child: const Icon(Icons.info_outline_rounded,
                          size: 15, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        )),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 3),
                    Text(unit!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        )),
                  ],
                ],
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(hint!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// QualityFlagCard
// ══════════════════════════════════════════════════════════════════════════════
class _QualityFlagCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String statusLabel;
  final bool isNegative;
  final bool isPositive;
  final bool isNeutralValue;
  final String? tooltip;

  const _QualityFlagCard({
    required this.icon,
    required this.label,
    required this.statusLabel,
    required this.isNegative,
    required this.isPositive,
    this.isNeutralValue = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color iconBg;
    final Color iconFg;
    final Color statusColor;
    final IconData? statusIcon;

    if (isNeutralValue) {
      bg = Colors.white;
      iconBg = AppColors.primary.withValues(alpha: 0.10);
      iconFg = AppColors.primary;
      statusColor = AppColors.textPrimary;
      statusIcon = null;
    } else if (isNegative) {
      bg = AppColors.error.withValues(alpha: 0.08);
      iconBg = AppColors.error.withValues(alpha: 0.12);
      iconFg = AppColors.error;
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (isPositive) {
      bg = AppColors.success.withValues(alpha: 0.07);
      iconBg = AppColors.success.withValues(alpha: 0.12);
      iconFg = AppColors.success;
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else {
      bg = Colors.white;
      iconBg = AppColors.surfaceContainer;
      iconFg = AppColors.textSecondary;
      statusColor = AppColors.textMuted;
      statusIcon = null;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          final c = isNegative
              ? AppColors.error
              : isPositive
                  ? AppColors.success
                  : AppColors.primary;
          if (states.contains(WidgetState.hovered))  return c.withValues(alpha: 0.06);
          if (states.contains(WidgetState.pressed))  return c.withValues(alpha: 0.12);
          return Colors.transparent;
        }),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: iconFg),
                  ),
                  const Spacer(),
                  if (tooltip != null)
                    Tooltip(
                      message: tooltip!,
                      child: const Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  )),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (statusIcon != null) ...[
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Printability card + individual gauge row
// ══════════════════════════════════════════════════════════════════════════════
class _PrintabilityCard extends StatelessWidget {
  final STLFile file;
  const _PrintabilityCard({required this.file});

  @override
  Widget build(BuildContext context) {
    final gauges = <Widget>[];

    if (file.overhangRatio != null) {
      gauges.add(_PrintabilityGauge(
        label: 'Overhang Ratio',
        displayValue:
            '${(file.overhangRatio! * 100).toStringAsFixed(1)}%',
        fillFraction: file.overhangRatio!.clamp(0.0, 1.0),
        colorScore: (1.0 - file.overhangRatio!).clamp(0.0, 1.0),
        description: file.maxOverhangAngle != null
            ? 'Max overhang angle: ${file.maxOverhangAngle!.toStringAsFixed(0)}°'
            : null,
      ));
    }

    if (file.minWallThicknessMm != null) {
      if (gauges.isNotEmpty) gauges.add(_divider);
      gauges.add(_PrintabilityGauge(
        label: 'Min Wall Thickness',
        displayValue:
            '${file.minWallThicknessMm!.toStringAsFixed(1)} mm',
        fillFraction: (file.minWallThicknessMm! / 6.0).clamp(0.0, 1.0),
        colorScore: (file.minWallThicknessMm! / 6.0).clamp(0.0, 1.0),
        description: file.avgWallThicknessMm != null
            ? 'Avg wall: ${file.avgWallThicknessMm!.toStringAsFixed(1)} mm'
            : null,
      ));
    }

    if (file.complexityIndex != null) {
      if (gauges.isNotEmpty) gauges.add(_divider);
      gauges.add(_PrintabilityGauge(
        label: 'Complexity Index',
        displayValue: file.complexityIndex!.toStringAsFixed(1),
        fillFraction: (file.complexityIndex! / 15.0).clamp(0.0, 1.0),
        colorScore:
            (1.0 - (file.complexityIndex! / 15.0)).clamp(0.0, 1.0),
        description:
            'Surface area / volume ratio — lower means simpler geometry.',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_heart_outlined,
                  size: 20, color: Color(0xFF4A5200)),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Printability Indicators',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                Text('How easy this part will be to print',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    )),
              ],
            ),
          ]),
          const SizedBox(height: 20),
          ...gauges,
        ],
      ),
    );
  }

  static const _divider = Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(color: AppColors.outlineVariant, height: 1),
  );
}

class _PrintabilityGauge extends StatelessWidget {
  final String label;
  final String displayValue;
  final double fillFraction; // 0..1 — bar width
  final double colorScore;   // 0..1 — drives colour & tag (1 = best)
  final String? description;

  const _PrintabilityGauge({
    required this.label,
    required this.displayValue,
    required this.fillFraction,
    required this.colorScore,
    this.description,
  });

  (Color, String) get _score {
    final pct = colorScore * 100;
    if (pct >= 80) return (AppColors.success, 'EXCELLENT');
    if (pct >= 50) return (AppColors.warning, 'FAIR');
    if (pct >= 25) return (const Color(0xFFF97316), 'FAIR');
    return (AppColors.error, 'POOR');
  }

  @override
  Widget build(BuildContext context) {
    final (color, tag) = _score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ),
            Text(displayValue,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Stack(children: [
              Container(color: AppColors.surfaceContainer),
              FractionallySizedBox(
                widthFactor: fillFraction,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ]),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(description!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// "Ready for AI Analysis" footer pill
// ══════════════════════════════════════════════════════════════════════════════
class _ReadyForAIPill extends StatelessWidget {
  const _ReadyForAIPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, size: 17, color: Color(0xFF1A1A00)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ready for AI Analysis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                SizedBox(height: 2),
                Text(
                  'Select an orientation in the Orientation tab, then continue to get a personalised print recommendation.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared layout helpers
// ══════════════════════════════════════════════════════════════════════════════
Widget _pair(Widget left, Widget right) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );

String _fmtInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
