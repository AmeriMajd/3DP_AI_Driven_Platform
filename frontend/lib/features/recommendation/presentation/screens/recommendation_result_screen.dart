import 'dart:math' as math;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/alternative_recommendation.dart';
import '../../domain/recommend_request.dart';
import '../../domain/recommendation_result.dart';
import '../providers/recommendation_providers.dart';
import '../widgets/star_rating_widget.dart';
import '../../../jobs/presentation/widgets/submit_job_dialog.dart';
import '../../../upload/presentation/providers/upload_providers.dart';

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

  bool _isEditing = false;
  RecommendationResult? _localResult;
  String? _editTech;
  String? _editMaterial;
  double? _editLayerHeight;
  int? _editInfill;
  int? _editPrintSpeed;
  int? _editWallCount;
  int? _editCoolingFan;
  int? _editSupportDensity;
  bool _isSaving = false;
  bool _isExporting = false;

  RecommendationResult? get _r => _localResult ?? widget.result;

  @override
  void dispose() {
    _clarificationCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    final r = _r;
    if (r == null) return;
    setState(() {
      _isEditing = true;
      _editTech = r.technology;
      _editMaterial = r.material;
      _editLayerHeight = r.layerHeight;
      _editInfill = r.infillDensity;
      _editPrintSpeed = r.printSpeed;
      _editWallCount = r.wallCount;
      _editCoolingFan = r.coolingFan;
      _editSupportDensity = r.supportDensity;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editTech = null;
      _editMaterial = null;
      _editLayerHeight = null;
      _editInfill = null;
      _editPrintSpeed = null;
      _editWallCount = null;
      _editCoolingFan = null;
      _editSupportDensity = null;
    });
  }

  Future<void> _saveEdits() async {
    final r = _r;
    if (r == null) return;

    final changed = <String, dynamic>{};
    if (_editTech != null && _editTech != r.technology) changed['technology'] = _editTech;
    if (_editMaterial != null && _editMaterial != r.material) changed['material'] = _editMaterial;
    if (_editLayerHeight != null && _editLayerHeight != r.layerHeight) changed['layer_height'] = _editLayerHeight;
    if (_editInfill != null && _editInfill != r.infillDensity) changed['infill_density'] = _editInfill;
    if (_editPrintSpeed != null && _editPrintSpeed != r.printSpeed) changed['print_speed'] = _editPrintSpeed;
    if (_editWallCount != null && _editWallCount != r.wallCount) changed['wall_count'] = _editWallCount;
    if (_editCoolingFan != null && _editCoolingFan != r.coolingFan) changed['cooling_fan'] = _editCoolingFan;
    if (_editSupportDensity != null && _editSupportDensity != r.supportDensity) changed['support_density'] = _editSupportDensity;

    if (changed.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(recommendationViewModelProvider.notifier).updateParameters(r.id, changed);
      if (mounted) {
        setState(() {
          _localResult = ref.read(recommendationViewModelProvider).result;
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resubmitWithClarification() async {
    final r = _r;
    if (r == null) return;
    setState(() => _isResubmitting = true);
    try {
      await ref.read(recommendationViewModelProvider.notifier).submit(
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
        final newResult = ref.read(recommendationViewModelProvider).result;
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

  Future<void> _exportProfile(String slicer) async {
    final r = _r;
    if (r == null) return;
    setState(() => _isExporting = true);
    try {
      final bytes = await ref
          .read(recommendationRepositoryProvider)
          .exportProfile(r.id, slicer);

      final tech = (r.technology ?? 'FDM').toUpperCase();
      final mat = r.material ?? 'Unknown';
      final ext = slicer == 'cura' ? 'inst.cfg' : 'ini';
      final filename = '3DP_AI_${tech}_$mat.$ext';

      await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        mimeType: MimeType.other,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$filename saved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Export to Slicer',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Download print parameters as a slicer config file.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _SlicerOption(
              icon: Icons.settings_outlined,
              label: 'Cura 5+',
              subtitle: '.inst.cfg — import via Preferences › Profiles',
              onTap: () {
                Navigator.pop(context);
                _exportProfile('cura');
              },
            ),
            const SizedBox(height: 12),
            _SlicerOption(
              icon: Icons.tune_rounded,
              label: 'PrusaSlicer 2+',
              subtitle: '.ini — import via File › Import › Import Config',
              onTap: () {
                Navigator.pop(context);
                _exportProfile('prusaslicer');
              },
            ),
          ],
        ),
      ),
    );
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

      // ── See all recommendations ──────────────────────────────────────────
      Center(
        child: TextButton.icon(
          icon: const Icon(Icons.history_rounded, size: 16),
          label: const Text('See all my recommendations'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          onPressed: () => context.push(AppRoutes.recommendHistory),
        ),
      ),
      const SizedBox(height: 8),

      // ── Actions ─────────────────────────────────────────────────────────
      _buildActionButtons(context),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Section A — Technology + Material Card
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTechMaterialCard(RecommendationResult r, String tier) {
    if (_isEditing) return _buildTechMaterialCardEdit(r, tier);
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

  Widget _buildTechMaterialCardEdit(RecommendationResult r, String tier) {
    final tierColor = _tierColor(tier);
    final overallConf =
        ((r.technologyConfidence ?? 0) + (r.materialConfidence ?? 0)) / 2;
    final confidencePct = (overallConf * 100).round();
    final aiMaterial = widget.result?.material;

    const fdmMaterials = ['PLA', 'PETG', 'ABS', 'TPU'];
    const slaMaterials = ['Resin-Std', 'Resin-Eng'];
    final materials = _editTech == 'SLA' ? slaMaterials : fdmMaterials;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Technology pill row ─────────────────────────────────────────
          const Text(
            'Technology',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['FDM', 'SLA'].map((tech) {
                final active = _editTech == tech;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final newMats =
                          tech == 'SLA' ? slaMaterials : fdmMaterials;
                      setState(() {
                        _editTech = tech;
                        _editMaterial = newMats.first;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tech,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Material chips ──────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Material',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (aiMaterial != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AI: $aiMaterial',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: materials.map((mat) {
              final selected = _editMaterial == mat;
              return GestureDetector(
                onTap: () => setState(() => _editMaterial = mat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.primary : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFE5E5EA),
                    ),
                  ),
                  child: Text(
                    mat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Confidence banner (read-only) ───────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tierColor.withValues(alpha: 0.2)),
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
    if (_isEditing) return _buildParametersCardEdit(r);
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

  Widget _buildParametersCardEdit(RecommendationResult r) {
    final isSLA = _editTech == 'SLA';
    final lhVal = (_editLayerHeight ?? r.layerHeight ?? 0.20)
        .clamp(r.layerHeightMin ?? 0.05, r.layerHeightMax ?? 0.35);
    final infillVal = (_editInfill ?? r.infillDensity ?? 20).toDouble();
    final speedVal = (_editPrintSpeed ?? r.printSpeed ??
            (isSLA ? 30 : 60))
        .toDouble();
    final wallVal = _editWallCount ?? r.wallCount ?? 2;
    final fanVal = (_editCoolingFan ?? r.coolingFan ?? 80).toDouble();
    final supportVal = (_editSupportDensity ?? r.supportDensity ?? 15).toDouble();

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

          // Layer Height
          _editParamSlider(
            icon: Icons.layers_rounded,
            iconColor: AppColors.primary,
            label: 'Layer Height',
            displayValue:
                '${lhVal.toStringAsFixed(2)} mm',
            value: lhVal,
            min: r.layerHeightMin ?? 0.05,
            max: r.layerHeightMax ?? 0.35,
            divisions: 30,
            onChanged: (v) => setState(
                () => _editLayerHeight = double.parse(v.toStringAsFixed(2))),
          ),
          _divider(),

          // Infill Density
          if (isSLA)
            _paramItem(
              icon: Icons.grid_4x4_rounded,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Infill Density',
              value: 'N/A — solid resin print',
              isNA: true,
            )
          else
            _editParamSlider(
              icon: Icons.grid_4x4_rounded,
              iconColor: const Color(0xFF8B5CF6),
              label: 'Infill Density',
              displayValue: '${infillVal.round()}%',
              value: infillVal,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _editInfill = v.round()),
            ),
          _divider(),

          // Print Speed
          _editParamSlider(
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFF0EA5E9),
            label: 'Print Speed',
            displayValue: '${speedVal.round()} mm/s',
            value: speedVal.clamp(isSLA ? 10.0 : 20.0, isSLA ? 80.0 : 150.0),
            min: isSLA ? 10 : 20,
            max: isSLA ? 80 : 150,
            divisions: isSLA ? 14 : 26,
            onChanged: (v) => setState(() => _editPrintSpeed = v.round()),
          ),
          _divider(),

          // Wall Line Count (stepper)
          if (isSLA)
            _paramItem(
              icon: Icons.border_all_rounded,
              iconColor: const Color(0xFF22C55E),
              label: 'Wall Line Count',
              value: 'N/A — solid resin print',
              isNA: true,
            )
          else
            _editParamStepper(
              icon: Icons.border_all_rounded,
              iconColor: const Color(0xFF22C55E),
              label: 'Wall Line Count',
              value: wallVal,
              min: 1,
              max: 10,
              onChanged: (v) => setState(() => _editWallCount = v),
            ),
          _divider(),

          // Cooling Fan
          if (isSLA)
            _paramItem(
              icon: Icons.air_rounded,
              iconColor: const Color(0xFF64748B),
              label: 'Cooling Fan',
              value: 'N/A — solid resin print',
              isNA: true,
            )
          else
            _editParamSlider(
              icon: Icons.air_rounded,
              iconColor: const Color(0xFF64748B),
              label: 'Cooling Fan',
              displayValue: '${fanVal.round()}%',
              value: fanVal,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _editCoolingFan = v.round()),
            ),
          _divider(),

          // Support Density
          _editParamSlider(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFFF59E0B),
            label: 'Support Density',
            displayValue: supportVal.round() == 0
                ? 'No supports'
                : '${supportVal.round()}%',
            value: supportVal,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _editSupportDensity = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _editParamSlider({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String displayValue,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      displayValue,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor:
                        AppColors.primary.withValues(alpha: 0.15),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editParamStepper({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
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
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: value <= min
                    ? AppColors.textSecondary
                    : AppColors.primary,
                onPressed: value <= min ? null : () => onChanged(value - 1),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: value >= max
                    ? AppColors.textSecondary
                    : AppColors.primary,
                onPressed: value >= max ? null : () => onChanged(value + 1),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
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
                ?subWidget,
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
              .read(recommendationViewModelProvider.notifier)
              .rate(r.id, rating);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Common scaffold pieces
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActionButtons(BuildContext context) {
    if (_isEditing) return _buildEditBottomBar(context);
    final r = _r;
    final stlFileName = r == null
        ? null
        : ref.watch(stlFileProvider(r.stlFileId)).valueOrNull?.originalFilename;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: r == null
                ? null
                : () => SubmitJobDialog.show(
                      context,
                      stlFileId: r.stlFileId,
                      recommendationId: r.id,
                      stlFileName: stlFileName,
                      technology: r.technology,
                    ),
            icon: const Icon(Icons.print_rounded, size: 20),
            label: const Text(
              'Submit to Print',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : _showExportSheet,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
              _isExporting ? 'Exporting…' : 'Export to Slicer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditBottomBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancelEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.primary),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveEdits,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Changes ✓',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
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
      actions: [
        if (!_isEditing)
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
            onPressed: _r != null ? _enterEditMode : null,
          )
        else
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: _isSaving ? null : _cancelEdit,
          ),
      ],
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

class _SlicerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _SlicerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFAEAEB2), size: 20),
          ],
        ),
      ),
    );
  }
}

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
