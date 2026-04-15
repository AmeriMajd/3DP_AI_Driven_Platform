import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/alternative_recommendation.dart';
import '../../domain/recommendation_result.dart';
import '../providers/recommendation_provider.dart';
import '../widgets/star_rating_widget.dart';

class RecommendationResultScreen extends ConsumerWidget {
  final RecommendationResult? result;
  const RecommendationResultScreen({super.key, this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _appBar(context, 'AI Recommendations'),
        body: Center(
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
              const Text('Result unavailable',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Please go back and submit the form again.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.upload),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Back to uploads'),
              ),
            ],
          ),
        ),
      );
    }

    final r = result!;
    final overallConfidence =
        ((r.technologyConfidence ?? 0) + (r.materialConfidence ?? 0)) / 2;
    final confidencePct = (overallConfidence * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar(context, 'AI Recommendations',
          subtitle: 'Optimized settings for your model'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AI Confidence Score ───────────────────────────────────────
            _buildConfidenceCard(confidencePct, overallConfidence, r.confidenceTier),
            const SizedBox(height: 14),

            // ── Printing Technology ───────────────────────────────────────
            _buildTechnologyCard(r),
            const SizedBox(height: 14),

            // ── Material Selection ────────────────────────────────────────
            _buildMaterialCard(r),
            const SizedBox(height: 14),

            // ── Print Parameters ──────────────────────────────────────────
            _buildParametersCard(r),
            const SizedBox(height: 14),

            // ── Quality Prediction ────────────────────────────────────────
            _buildQualityPredictionCard(r),
            const SizedBox(height: 14),

            // ── Orientation (conditional) ─────────────────────────────────
            if (r.orientationRank != null) ...[
              _buildOrientationCard(r),
              const SizedBox(height: 14),
            ],

            // ── Clarification (conditional) ───────────────────────────────
            if (r.needsClarification && r.clarificationQuestion != null) ...[
              _buildClarificationBanner(r),
              const SizedBox(height: 14),
            ],

            // ── Alternatives (conditional) ────────────────────────────────
            if (r.confidenceTier != 'high' && r.alternative != null) ...[
              _buildAlternativeCard(r.alternative!),
              const SizedBox(height: 14),
            ],

            // ── AI Insight ────────────────────────────────────────────────
            _buildAiInsightCard(r),
            const SizedBox(height: 14),

            // ── Rating ────────────────────────────────────────────────────
            _buildRatingCard(r, ref),
            const SizedBox(height: 16),

            // ── Accept & Continue ─────────────────────────────────────────
            SizedBox(
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
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  AppBar _appBar(BuildContext context, String title, {String? subtitle}) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  // ── AI Confidence Score ───────────────────────────────────────────────────

  Widget _buildConfidenceCard(
      int pct, double raw, String? tier) {
    final color = _tierColor(tier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              const Text('AI Confidence Score',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: raw.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tierLabel(tier),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Based on your model geometry and intent profile',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Printing Technology ───────────────────────────────────────────────────

  Widget _buildTechnologyCard(RecommendationResult r) {
    final isFDM = r.technology == 'FDM';
    final techColor =
        isFDM ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9);
    final fullName = isFDM
        ? 'FDM (Fused Deposition Modeling)'
        : 'SLA (Stereolithography)';
    final whyText = isFDM
        ? 'Best balance of cost, strength, and precision for this geometry. Ideal for functional and structural parts.'
        : 'Highest surface quality for detailed models. Optimal for fine-feature decorative and prototype parts.';

    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Printing Technology',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              _StatusBadge(label: 'Recommended', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: techColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  r.technology ?? '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fullName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: techColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text('Why this technology?',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(whyText,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Material Selection ────────────────────────────────────────────────────

  Widget _buildMaterialCard(RecommendationResult r) {
    final matColor = _materialColor(r.material);
    final matBenefits = _materialBenefits(r.material, r.intendedUse);

    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Material Selection',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              _StatusBadge(label: 'Optimal', color: const Color(0xFF0EA5E9)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    color: matColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                r.material ?? '—',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (r.materialConfidence != null)
                Text(
                  '${(r.materialConfidence! * 100).round()}%',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.7)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text('Material Benefits',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(matBenefits,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Print Parameters ──────────────────────────────────────────────────────

  Widget _buildParametersCard(RecommendationResult r) {
    String layerHeightVal;
    if (r.layerHeight != null && r.layerHeightMin != null) {
      layerHeightVal = '${r.layerHeightMin}–${r.layerHeightMax} mm';
    } else {
      layerHeightVal = '${r.layerHeight ?? "—"} mm';
    }

    final params = [
      _ParamRow(Icons.layers_rounded, 'Layer Height', layerHeightVal,
          const Color(0xFF6366F1)),
      _ParamRow(Icons.grid_4x4_rounded, 'Infill Density',
          '${r.infillDensity ?? "—"}%', const Color(0xFF8B5CF6)),
      _ParamRow(Icons.speed_rounded, 'Print Speed',
          '${r.printSpeed ?? "—"} mm/s', const Color(0xFF0EA5E9)),
      _ParamRow(
          Icons.support_agent_rounded,
          'Support',
          r.supportDensity == 0 ? 'None' : '${r.supportDensity ?? "—"}%',
          const Color(0xFFF59E0B)),
    ];

    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Print Parameters',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          ...params.map((p) => _buildParamRow(p)),
          // Extra params in an expandable
          Theme(
            data: ThemeData(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More parameters',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              children: [
                _buildParamRow(_ParamRow(Icons.border_outer_rounded,
                    'Wall Lines', '${r.wallCount ?? "—"}',
                    const Color(0xFF22C55E))),
                _buildParamRow(_ParamRow(Icons.air_rounded, 'Cooling Fan',
                    '${r.coolingFan ?? "—"}%', const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(_ParamRow p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(p.icon, color: p.color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p.label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(p.value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Optimal',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  // ── Quality Prediction ────────────────────────────────────────────────────

  Widget _buildQualityPredictionCard(RecommendationResult r) {
    final bars = [
      ('Quality', r.qualityScore ?? 0, const Color(0xFF6366F1)),
      ('Efficiency', r.costScore ?? 0, const Color(0xFF22C55E)),
      ('Speed', r.speedScore ?? 0, const Color(0xFF0EA5E9)),
    ];

    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quality Prediction',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...bars.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b.$1,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        Text('${b.$2}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: b.$3)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: b.$2 / 100,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE5E5EA),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(b.$3),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Orientation ───────────────────────────────────────────────────────────

  Widget _buildOrientationCard(RecommendationResult r) {
    return _ResultCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.threed_rotation_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected Orientation',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Rank ${r.orientationRank} orientation applied',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${r.orientationRank}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── Clarification ─────────────────────────────────────────────────────────

  Widget _buildClarificationBanner(RecommendationResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Refine for better results',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(r.clarificationQuestion!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Alternatives ──────────────────────────────────────────────────────────

  Widget _buildAlternativeCard(AlternativeRecommendation alt) {
    return _ResultCard(
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.compare_arrows_rounded,
                color: Color(0xFF64748B), size: 18),
          ),
          title: const Text('Alternative Option',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          subtitle: Text('${alt.technology} · ${alt.material}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                _buildScoreChip('Quality', alt.qualityScore,
                    const Color(0xFF6366F1)),
                const SizedBox(width: 8),
                _buildScoreChip(
                    'Cost', alt.costScore, const Color(0xFF22C55E)),
                const SizedBox(width: 8),
                _buildScoreChip(
                    'Speed', alt.speedScore, const Color(0xFF0EA5E9)),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreChip(String label, int score, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$score',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── AI Insight ────────────────────────────────────────────────────────────

  Widget _buildAiInsightCard(RecommendationResult r) {
    final insight =
        'These settings for ${r.technology ?? "FDM"} with ${r.material ?? "PLA"} '
        'will save approximately ${r.speedScore ?? 70}% of standard print time '
        'while achieving ${r.qualityScore ?? 80}% quality output. '
        'Layer height ${r.layerHeight ?? 0.2} mm is optimised for your surface finish preference.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFF59E0B), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Insight',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(insight,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rating ────────────────────────────────────────────────────────────────

  Widget _buildRatingCard(RecommendationResult r, WidgetRef ref) {
    return _ResultCard(
      child: StarRatingWidget(
        currentRating: r.userRating,
        onRate: (rating) async {
          await ref.read(recommendationProvider.notifier).rate(r.id, rating);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  String _tierLabel(String? tier) {
    switch (tier) {
      case 'high':
        return 'HIGH CONFIDENCE';
      case 'medium':
        return 'MEDIUM CONFIDENCE';
      default:
        return 'LOW CONFIDENCE';
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

  String _materialBenefits(String? material, String intendedUse) {
    switch (material) {
      case 'PLA':
        return 'Optimal mechanical properties and cost-effectiveness. Easy to print with excellent dimensional accuracy. Best choice for $intendedUse applications.';
      case 'PETG':
        return 'Superior chemical resistance and impact strength compared to PLA. Excellent layer adhesion and slight flexibility. Ideal for functional parts.';
      case 'ABS':
        return 'High temperature resistance and toughness. Post-processing friendly (acetone smoothing). Best for durable mechanical components.';
      case 'TPU':
        return 'Flexible and rubber-like properties. Excellent shock absorption. Perfect when the part needs to flex, bend, or compress.';
      case 'Resin-Std':
        return 'Ultra-smooth surface finish with fine detail reproduction. Ideal for decorative and display models requiring high visual quality.';
      case 'Resin-Eng':
        return 'Engineering-grade resin with superior mechanical properties. Heat and chemical resistant. For demanding functional applications.';
      default:
        return 'Optimal properties for your selected use case and geometry.';
    }
  }
}

// ── Shared private widgets ────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final Widget child;
  const _ResultCard({required this.child});

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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _ParamRow {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ParamRow(this.icon, this.label, this.value, this.color);
}
