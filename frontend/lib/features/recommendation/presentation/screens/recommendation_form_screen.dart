import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../upload/presentation/providers/upload_providers.dart';
import '../../domain/recommend_request.dart';
import '../providers/recommendation_providers.dart';
import '../../domain/recommendation_state.dart';

class RecommendationFormScreen extends ConsumerStatefulWidget {
  final String fileId;
  final int? orientationRank;

  const RecommendationFormScreen({
    super.key,
    required this.fileId,
    this.orientationRank,
  });

  @override
  ConsumerState<RecommendationFormScreen> createState() =>
      _RecommendationFormScreenState();
}

class _RecommendationFormScreenState
    extends ConsumerState<RecommendationFormScreen> {
  String _intendedUse = 'functional';
  String _surfaceFinish = 'standard';
  bool _needsFlexibility = false;
  String _strengthRequired = 'medium';
  String _budgetPriority = 'quality';
  bool _outdoorUse = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recommendationViewModelProvider.notifier).reset();
    });
  }

  void _submit() {
    ref.read(recommendationViewModelProvider.notifier).submit(
          RecommendRequest(
            fileId: widget.fileId,
            orientationRank: widget.orientationRank,
            intendedUse: _intendedUse,
            surfaceFinish: _surfaceFinish,
            needsFlexibility: _needsFlexibility,
            strengthRequired: _strengthRequired,
            budgetPriority: _budgetPriority,
            outdoorUse: _outdoorUse,
          ),
        );
  }

  String _getAiTip() {
    switch (_intendedUse) {
      case 'decorative':
        return 'For decorative parts, a fine layer height (0.12 mm) with 10% infill achieves a premium surface finish while minimising material use.';
      case 'prototype':
        return 'For rapid prototyping, cost-efficiency is key. Consider SLA if your prototype requires fine details or smooth organic surfaces.';
      default:
        return 'For functional parts, PETG offers the best balance of rigidity and layer adhesion. Medium infill (30–40%) is optimal for most mechanical loads.';
    }
  }

  // ── Tooltip helpers ───────────────────────────────────────────────────────

  void _showTooltip(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoIcon(String title, String message) {
    return GestureDetector(
      onTap: () => _showTooltip(context, title, message),
      child: Container(
        padding: const EdgeInsets.all(2),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── Section label with tooltip ────────────────────────────────────────────

  Widget _buildLabel(String text, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 6),
            _infoIcon(text, tooltip),
          ],
        ],
      ),
    );
  }

  // ── Sub-label (description under section title) ───────────────────────────

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recommendationViewModelProvider);
    final isLoading = state.status == RecommendationStatus.loading;

    ref.listen(recommendationViewModelProvider, (_, next) {
      if (next.status == RecommendationStatus.success && next.result != null) {
        context.pushReplacement(AppRoutes.recommendResult, extra: next.result);
      }
    });

    final file = ref
        .watch(uploadViewModelProvider)
        .files
        .where((f) => f.id == widget.fileId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'AI Configuration',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File summary ──────────────────────────────────────────────
            if (file != null) _buildFileSummary(file.originalFilename),

            // ── Error banner ──────────────────────────────────────────────
            if (state.status == RecommendationStatus.error &&
                state.errorMessage != null)
              _buildErrorBanner(state.errorMessage!),

            // ── Intended Use ──────────────────────────────────────────────
            _buildLabel(
              'Intended Use',
              tooltip:
                  'Defines how your part will be used in the real world. This directly influences the material selection, infill density, and print settings recommended by the AI.',
            ),
            _buildIntendedUseSection(),
            const SizedBox(height: 22),

            // ── Surface Finish ────────────────────────────────────────────
            _buildLabel(
              'Surface Finish',
              tooltip:
                  'Controls the layer height and visible surface quality.\n\n• Rough — fast print, visible layer lines (0.3 mm)\n• Standard — balanced quality and speed (0.2 mm)\n• Fine — smoother surface, longer print time (0.12 mm)',
            ),
            _buildSurfaceFinishSection(),
            const SizedBox(height: 22),

            // ── Needs Flexibility ─────────────────────────────────────────
            _buildToggleCard(
              icon: Icons.compare_arrows_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: 'Needs Flexibility',
              subtitle: 'Allow material deformation?',
              tooltip:
                  'Enable if your part must bend, compress, or absorb impact without breaking. Flexible parts require special filaments such as TPU or TPE.',
              value: _needsFlexibility,
              onChanged: (v) => setState(() => _needsFlexibility = v),
            ),
            const SizedBox(height: 22),

            // ── Strength Required ─────────────────────────────────────────
            _buildLabel(
              'Strength Required',
              tooltip:
                  'Sets the mechanical resistance of the printed part by adjusting wall thickness and infill density.\n\n• Low — 10–15% infill, thin walls (decorative only)\n• Medium — 20–30% infill, standard walls (everyday use)\n• High — 40–60% infill, thick walls (structural loads)',
            ),
            _buildSubLabel('Determines wall thickness and infill density.'),
            _buildIconGrid(
              options: const [
                _GridOption(
                  'low',
                  Icons.shield_outlined,
                  'Low',
                  Color(0xFF22C55E),
                  'Decorative only',
                ),
                _GridOption(
                  'medium',
                  Icons.tune_rounded,
                  'Medium',
                  Color(0xFFF59E0B),
                  'General use',
                ),
                _GridOption(
                  'high',
                  Icons.bolt_rounded,
                  'High',
                  Color(0xFFEF4444),
                  'Heavy loads',
                ),
              ],
              selected: _strengthRequired,
              onSelect: (v) => setState(() => _strengthRequired = v),
            ),
            const SizedBox(height: 22),

            // ── Budget Priority ───────────────────────────────────────────
            _buildLabel(
              'Budget Priority',
              tooltip:
                  'Tells the AI which trade-off to optimise for:\n\n• Cost — minimises material and print time\n• Quality — maximises surface finish and precision\n• Speed — reduces total print time even at a higher material cost',
            ),
            _buildIconGrid(
              options: const [
                _GridOption(
                  'cost',
                  Icons.savings_rounded,
                  'Cost',
                  Color(0xFF22C55E),
                  'Save material',
                ),
                _GridOption(
                  'quality',
                  Icons.diamond_rounded,
                  'Quality',
                  Color(0xFF6366F1),
                  'Best finish',
                ),
                _GridOption(
                  'speed',
                  Icons.speed_rounded,
                  'Speed',
                  Color(0xFFF59E0B),
                  'Fast print',
                ),
              ],
              selected: _budgetPriority,
              onSelect: (v) => setState(() => _budgetPriority = v),
            ),
            const SizedBox(height: 22),

            // ── Outdoor Exposure ──────────────────────────────────────────
            _buildToggleCard(
              icon: Icons.wb_sunny_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Outdoor Exposure',
              subtitle: 'Requires UV-stable material',
              tooltip:
                  'Parts left in sunlight degrade quickly with standard PLA. Enable this to filter for UV-resistant materials such as ASA, PETG, or ABS that resist yellowing and brittleness.',
              value: _outdoorUse,
              onChanged: (v) => setState(() => _outdoorUse = v),
            ),
            const SizedBox(height: 22),

            // ── AI Tip ────────────────────────────────────────────────────
            _buildAiTipCard(),
            const SizedBox(height: 28),

            // ── CTA button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 18),
                label: Text(
                  isLoading ? 'Analysing…' : 'Launch AI Analysis',
                  style: const TextStyle(
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

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _buildFileSummary(String filename) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.view_in_ar_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        widget.orientationRank != null
                            ? Icons.rotate_90_degrees_ccw_rounded
                            : Icons.help_outline_rounded,
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.orientationRank != null
                            ? 'Orientation #${widget.orientationRank} selected'
                            : 'No orientation selected',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.orientationRank != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.orientationRank}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntendedUseSection() {
    const options = [
      _IntendedOption(
        'functional',
        Icons.precision_manufacturing_rounded,
        Color(0xFF6366F1),
        'Functional',
        'Mechanical parts, high resistance',
      ),
      _IntendedOption(
        'decorative',
        Icons.palette_rounded,
        Color(0xFFEC4899),
        'Decorative',
        'Art, figurines, smooth visual surface',
      ),
      _IntendedOption(
        'prototype',
        Icons.science_rounded,
        Color(0xFFF59E0B),
        'Prototype',
        'Quick validation, fast iteration',
      ),
    ];

    return Column(
      children: options.map((opt) {
        final isSelected = _intendedUse == opt.value;
        return GestureDetector(
          onTap: () => setState(() => _intendedUse = opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isSelected ? opt.color.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? opt.color : const Color(0xFFE5E5EA),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? opt.color.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.14)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    opt.icon,
                    color: isSelected ? opt.color : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? opt.color : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isSelected ? opt.color : const Color(0xFFD1D5DB),
                      width: isSelected ? 0 : 1.5,
                    ),
                    color: isSelected ? opt.color : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSurfaceFinishSection() {
    const options = [
      (
        'rough',
        'Rough',
        Icons.grain_rounded,
      ),
      (
        'standard',
        'Standard',
        Icons.layers_rounded,
      ),
      (
        'fine',
        'Fine',
        Icons.blur_on_rounded,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _surfaceFinish == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _surfaceFinish = opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.$3,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    _infoIcon(title, tooltip),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E5EA),
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid({
    required List<_GridOption> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Row(
      children: options.asMap().entries.map((e) {
        final idx = e.key;
        final opt = e.value;
        final isSelected = selected == opt.value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(
                left: idx == 0 ? 0 : 5,
                right: idx == options.length - 1 ? 0 : 5,
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? opt.color.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? opt.color : const Color(0xFFE5E5EA),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? opt.color.withValues(alpha: 0.15)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      opt.icon,
                      color: isSelected ? opt.color : AppColors.textSecondary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? opt.color : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt.subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAiTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: Color(0xFFD97706), size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Tip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getAiTip(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78350F),
                    height: 1.45,
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

// ── Data classes ──────────────────────────────────────────────────────────────

class _IntendedOption {
  final String value;
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  const _IntendedOption(
      this.value, this.icon, this.color, this.label, this.subtitle);
}

class _GridOption {
  final String value;
  final IconData icon;
  final String label;
  final Color color;
  final String subtitle;
  const _GridOption(
      this.value, this.icon, this.label, this.color, this.subtitle);
}
