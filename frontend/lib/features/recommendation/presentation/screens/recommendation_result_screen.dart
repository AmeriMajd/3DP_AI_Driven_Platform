import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/alternative_recommendation.dart';
import '../../domain/recommend_request.dart';
import '../../domain/recommendation_result.dart';
import '../providers/recommendation_provider.dart';
import '../widgets/star_rating_widget.dart';

class RecommendationResultScreen extends ConsumerStatefulWidget {
  final RecommendationResult? result;
  const RecommendationResultScreen({super.key, this.result});

  @override
  ConsumerState<RecommendationResultScreen> createState() =>
      _RecommendationResultScreenState();
}

class _RecommendationResultScreenState
    extends ConsumerState<RecommendationResultScreen> {
  // 0 = main recommendation, 1 = alternative (medium tier tab switcher)
  int _activeTab = 0;
  bool _altExpanded = false;
  final _clarificationCtrl = TextEditingController();
  bool _isResubmitting = false;

  RecommendationResult? get _r => widget.result;

  @override
  void dispose() {
    _clarificationCtrl.dispose();
    super.dispose();
  }

  Future<void> _resubmitWithClarification() async {
    final r = _r;
    if (r == null) return;
    setState(() => _isResubmitting = true);
    try {
      await ref.read(recommendationProvider.notifier).submit(
            RecommendRequest(
              fileId: r.stlFileId,
              orientationRank: r.orientationRank,
              intendedUse: r.intendedUse,
              surfaceFinish: r.surfaceFinish,
              needsFlexibility: r.needsFlexibility,
              strengthRequired: r.strengthRequired,
              budgetPriority: r.budgetPriority,
              outdoorUse: r.outdoorUse,
            ),
          );
      if (mounted) {
        final newResult = ref.read(recommendationProvider).result;
        if (newResult != null) {
          context.pushReplacement(AppRoutes.recommendResult, extra: newResult);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_r == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: _buildAppBar(context),
        body: _buildErrorBody(context),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildSections(context),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final r = _r!;
    final tier = r.confidenceTier ?? 'low';
    final isMedium = tier == 'medium';
    final showAlt = isMedium && _activeTab == 1 && r.alternative != null;

    return [
      // ── A: Technology + Material ────────────────────────────────────────
      _buildTechMaterialCard(r, tier),
      const SizedBox(height: 14),

      // ── Tab switcher (medium tier only) ────────────────────────────────
      if (isMedium && r.alternative != null) ...[
        _buildTechTabSwitcher(r),
        const SizedBox(height: 14),
      ],

      // ── B: Print Parameters ─────────────────────────────────────────────
      _buildParametersCard(r, showAlt),
      const SizedBox(height: 14),

      // ── C: Performance Scores ───────────────────────────────────────────
      _buildScoresCard(r, showAlt),
      const SizedBox(height: 14),

      // ── D: Orientation Preview ──────────────────────────────────────────
      if (r.orientationRank != null) ...[
        _buildOrientationCard(r),
        const SizedBox(height: 14),
      ],

      // ── E: Clarification Banner (low tier) ──────────────────────────────
      if (tier == 'low' &&
          r.needsClarification &&
          r.clarificationQuestion != null) ...[
        _buildClarificationCard(r),
        const SizedBox(height: 14),
      ],

      // ── F: Alternatives (low / high — expandable) ───────────────────────
      if (!isMedium && r.alternative != null) ...[
        _buildAlternativeExpandable(r.alternative!, r),
        const SizedBox(height: 14),
      ],

      // ── G: Rating ───────────────────────────────────────────────────────
      _buildRatingCard(r),
      const SizedBox(height: 16),

      // ── Accept & Continue ────────────────────────────────────────────────
      _buildContinueButton(context),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section A — Technology + Material Card
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTechMaterialCard(RecommendationResult r, String tier) {
    final tierColor = _tierColor(tier);
    final matColor = _materialColor(r.material);
    final overallConf =
        ((r.technologyConfidence ?? 0) + (r.materialConfidence ?? 0)) / 2;
    final confidencePct = (overallConf * 100).round();
    final description = _materialDescription(r.material, r.intendedUse);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Printer icon + tech badge + material dot ────────────────────
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 10),
              _TechBadge(label: r.technology ?? 'FDM'),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: matColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    r.material ?? '—',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Confidence banner ───────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: tierColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_tierIcon(tier), color: tierColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _tierLabel(tier),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tierColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: overallConf.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor:
                              tierColor.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(tierColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$confidencePct%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tierColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Description ─────────────────────────────────────────────────
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Tab Switcher (medium tier)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTechTabSwitcher(RecommendationResult r) {
    final alt = r.alternative!;
    final labels = [r.technology ?? 'FDM', alt.technology];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(2, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section B — Print Parameters
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _activeParams(RecommendationResult r, bool showAlt) {
    if (showAlt && r.alternative != null) {
      final a = r.alternative!;
      return {
        'layerHeight': a.layerHeight,
        'layerHeightMin': null,
        'layerHeightMax': null,
        'infillDensity': a.infillDensity,
        'printSpeed': a.printSpeed,
        'wallCount': a.wallCount,
        'coolingFan': a.coolingFan,
        'supportDensity': a.supportDensity,
        'isSLA': a.technology == 'SLA',
      };
    }
    return {
      'layerHeight': r.layerHeight,
      'layerHeightMin': r.layerHeightMin,
      'layerHeightMax': r.layerHeightMax,
      'infillDensity': r.infillDensity,
      'printSpeed': r.printSpeed,
      'wallCount': r.wallCount,
      'coolingFan': r.coolingFan,
      'supportDensity': r.supportDensity,
      'isSLA': r.technology == 'SLA',
    };
  }

  Widget _buildParametersCard(RecommendationResult r, bool showAlt) {
    final p = _activeParams(r, showAlt);
    final isSLA = p['isSLA'] as bool;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Print Parameters',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _buildLayerHeightParam(p),
          _divider(),
          _paramItem(
            icon: Icons.grid_4x4_rounded,
            iconColor: const Color(0xFF8B5CF6),
            label: 'Infill Density',
            value: isSLA
                ? 'N/A — solid resin print'
                : (p['infillDensity'] != null ? '${p['infillDensity']}%' : '—'),
            isNA: isSLA,
          ),
          _divider(),
          _paramItem(
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFF0EA5E9),
            label: 'Print Speed',
            value: p['printSpeed'] != null ? '${p['printSpeed']} mm/s' : '—',
          ),
          _divider(),
          _paramItem(
            icon: Icons.border_all_rounded,
            iconColor: const Color(0xFF22C55E),
            label: 'Wall Line Count',
            value: isSLA
                ? 'N/A — solid resin print'
                : (p['wallCount'] != null ? '${p['wallCount']}' : '—'),
            isNA: isSLA,
          ),
          _divider(),
          _paramItem(
            icon: Icons.air_rounded,
            iconColor: const Color(0xFF64748B),
            label: 'Cooling Fan',
            value: isSLA
                ? 'N/A — solid resin print'
                : (p['coolingFan'] != null ? '${p['coolingFan']}%' : '—'),
            isNA: isSLA,
          ),
          _divider(),
          _paramItem(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Support Density',
            value: p['supportDensity'] == 0
                ? 'No supports needed'
                : (p['supportDensity'] != null ? '${p['supportDensity']}%' : '—'),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerHeightParam(Map<String, dynamic> p) {
    final layerHeight = p['layerHeight'] as double?;

    if (layerHeight == null) {
      return _paramItem(
        icon: Icons.layers_rounded,
        iconColor: AppColors.primary,
        label: 'Layer Height',
        value: '—',
      );
    }

    final minH = p['layerHeightMin'] as double?;
    final maxH = p['layerHeightMax'] as double?;

    return _paramItem(
      icon: Icons.layers_rounded,
      iconColor: AppColors.primary,
      label: 'Layer Height',
      value: '${layerHeight.toStringAsFixed(2)} mm',
      subWidget: (minH != null && maxH != null) ? _rangeBar(layerHeight, minH, maxH) : null,
    );
  }

  Widget _rangeBar(double value, double min, double max) {
    final progress =
        max > min ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.5;

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Text('$min',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Track
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Thumb
                    Positioned(
                      left: (progress * w - 6).clamp(0.0, w - 12),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text('$max',
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _paramItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? subWidget,
    bool isNA = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isNA
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontStyle:
                        isNA ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (subWidget case final w?) w,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEF0));

  // ═══════════════════════════════════════════════════════════════════════════
  // Section C — Performance Scores
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildScoresCard(RecommendationResult r, bool showAlt) {
    final alt = r.alternative;
    final cost =
        showAlt && alt != null ? alt.costScore : (r.costScore ?? 0);
    final quality =
        showAlt && alt != null ? alt.qualityScore : (r.qualityScore ?? 0);
    final speed =
        showAlt && alt != null ? alt.speedScore : (r.speedScore ?? 0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Scores',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ScoreCircle(
                label: 'Cost',
                subLabel: 'Material & energy\nefficiency',
                score: cost,
              ),
              _ScoreCircle(
                label: 'Quality',
                subLabel: 'Surface finish &\naccuracy',
                score: quality,
              ),
              _ScoreCircle(
                label: 'Speed',
                subLabel: 'Total print time',
                score: speed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section D — Orientation Preview
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOrientationCard(RecommendationResult r) {
    String fmtAngle(double? v) => v != null ? '${v.toStringAsFixed(1)}°' : '—';

    final overhang = r.overhangReductionPct;
    final height = r.orientationPrintHeightMm;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.threed_rotation_rounded,
                    color: AppColors.primary, size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'Orientation Preview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // RX / RY / RZ grid
          Row(
            children: [
              _angleCell('RX', fmtAngle(r.orientationRx)),
              const SizedBox(width: 8),
              _angleCell('RY', fmtAngle(r.orientationRy)),
              const SizedBox(width: 8),
              _angleCell('RZ', fmtAngle(r.orientationRz)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _orientationInfoCell(
                  label: 'OVERHANG\nREDUCTION',
                  value: overhang != null
                      ? '${overhang.toStringAsFixed(1)}%'
                      : '—',
                  warm: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _orientationInfoCell(
                  label: 'PRINT HEIGHT',
                  value: height != null
                      ? '${height.toStringAsFixed(1)} mm'
                      : 'Rank #${r.orientationRank}',
                  warm: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _angleCell(String axis, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              axis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orientationInfoCell({
    required String label,
    required String value,
    required bool warm,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: warm ? const Color(0xFFFFF8E7) : AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: warm
                  ? const Color(0xFF92400E)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: warm
                  ? const Color(0xFF78350F)
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section E — Clarification Banner
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildClarificationCard(RecommendationResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.clarificationQuestion!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    if (r.clarificationField != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Field: ${r.clarificationField}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _clarificationCtrl,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Your answer...',
                    hintStyle: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: AppColors.error, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed:
                    _isResubmitting ? null : _resubmitWithClarification,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isResubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section F — Alternatives (expandable)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAlternativeExpandable(
      AlternativeRecommendation alt, RecommendationResult r) {
    final altMatColor = _materialColor(alt.material);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () =>
                setState(() => _altExpanded = !_altExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'See alternative (${alt.technology} — ${alt.material})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _altExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded body
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _altExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFEEEEF0)),
                  const SizedBox(height: 14),
                  // Alt tech + material row
                  Row(
                    children: [
                      _TechBadge(
                          label: alt.technology, compact: true),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: altMatColor,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        alt.material,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(alt.confidence * 100).round()}% conf.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _altDescription(alt.technology, alt.material),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Alt scores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ScoreCircle(
                          label: 'Cost',
                          subLabel: 'Material cost',
                          score: alt.costScore),
                      _ScoreCircle(
                          label: 'Quality',
                          subLabel: 'Surface quality',
                          score: alt.qualityScore),
                      _ScoreCircle(
                          label: 'Speed',
                          subLabel: 'Print time',
                          score: alt.speedScore),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section G — Rating
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRatingCard(RecommendationResult r) {
    return _Card(
      child: StarRatingWidget(
        currentRating: r.userRating,
        onRate: (rating) async {
          await ref
              .read(recommendationProvider.notifier)
              .rate(r.id, rating);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Common scaffold pieces
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: () => context.go(AppRoutes.upload),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text(
          'Accept & Continue',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'AI Recommendation',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Result unavailable',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please go back and submit the form again.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.upload),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to uploads'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  Color _tierColor(String? tier) {
    switch (tier) {
      case 'high':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  IconData _tierIcon(String? tier) {
    switch (tier) {
      case 'high':
        return Icons.check_circle_rounded;
      case 'medium':
        return Icons.bolt_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _tierLabel(String? tier) {
    switch (tier) {
      case 'high':
        return '✓ High confidence';
      case 'medium':
        return '⚡ Moderate confidence — see alternative';
      default:
        return '? Low confidence — we need more context';
    }
  }

  Color _materialColor(String? material) {
    switch (material) {
      case 'PLA':
        return const Color(0xFF22C55E);
      case 'PETG':
        return const Color(0xFF0EA5E9);
      case 'ABS':
        return const Color(0xFFEF4444);
      case 'TPU':
        return const Color(0xFFF97316);
      case 'Resin-Std':
        return const Color(0xFF8B5CF6);
      case 'Resin-Eng':
        return const Color(0xFF6D28D9);
      default:
        return AppColors.textSecondary;
    }
  }

  String _materialDescription(String? material, String intendedUse) {
    switch (material) {
      case 'PLA':
        return 'PLA provides excellent dimensional accuracy and ease of printing, ideal for $intendedUse parts with good surface quality.';
      case 'PETG':
        return 'PETG provides excellent layer adhesion and chemical resistance, ideal for functional parts with moderate heat exposure.';
      case 'ABS':
        return 'ABS offers high temperature resistance and toughness, perfect for durable mechanical components in demanding environments.';
      case 'TPU':
        return 'TPU provides flexible, rubber-like properties with excellent shock absorption — ideal for parts that need to flex or compress.';
      case 'Resin-Std':
        return 'Standard resin delivers ultra-smooth surface finish with fine detail reproduction, perfect for high-visual-quality models.';
      case 'Resin-Eng':
        return 'Engineering resin offers superior mechanical properties with heat and chemical resistance for demanding functional applications.';
      default:
        return 'Optimal material selection for your model geometry and intended use case.';
    }
  }

  String _altDescription(String tech, String material) {
    if (tech == 'SLA') {
      return 'SLA offers superior surface finish but higher cost per part. Best for high-detail or decorative models.';
    }
    return 'FDM provides a cost-effective solution with good mechanical strength, suitable for most functional parts.';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared private widgets
// ══════════════════════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: child,
    );
  }
}

class _TechBadge extends StatelessWidget {
  final String label;
  final bool compact;
  const _TechBadge({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 15,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Score arc circle ──────────────────────────────────────────────────────────

class _ScoreCircle extends StatelessWidget {
  final String label;
  final String subLabel;
  final int score;

  const _ScoreCircle({
    required this.label,
    required this.subLabel,
    required this.score,
  });

  Color get _color {
    if (score >= 80) return const Color(0xFF22C55E);
    if (score >= 50) return const Color(0xFFF59E0B);
    if (score >= 25) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: CustomPaint(
            painter: _ArcPainter(
              progress: score / 100,
              color: _color,
              backgroundColor: const Color(0xFFE5E5EA),
              strokeWidth: 7,
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subLabel,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  // 270° arc: starts at -135° (-3π/4), sweeps 270° (3π/2)
  static const double _startAngle = -math.pi * 0.75;
  static const double _totalSweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background track
    canvas.drawArc(rect, _startAngle, _totalSweep, false,
        basePaint..color = backgroundColor);

    // Progress fill
    if (progress > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _totalSweep * progress.clamp(0.0, 1.0),
        false,
        basePaint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
