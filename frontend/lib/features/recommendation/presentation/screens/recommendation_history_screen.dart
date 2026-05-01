import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/recommendation_result.dart';
import '../providers/recommendation_history_provider.dart';

// ── Filter constants ──────────────────────────────────────────────────────────

const _techFilters = ['FDM', 'SLA'];

// label (displayed) → value (stored in DB / returned by API)
const _materialFilterMap = {
  'PLA': 'PLA',
  'PETG': 'PETG',
  'ABS': 'ABS',
  'TPU': 'TPU',
  'Resin-Std': 'Resin-Standard',
  'Resin-Eng': 'Resin-Engineering',
};

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class RecommendationHistoryScreen extends ConsumerWidget {
  const RecommendationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recommendationHistoryProvider);
    final tech = ref.watch(historyTechnologyFilterProvider);
    final mat = ref.watch(historyMaterialFilterProvider);
    final total = history.valueOrNull?.length;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
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
            const Text(
              'My Recommendations',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (total != null)
              Text(
                '$total ${total == 1 ? 'analysis' : 'analyses'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          _FilterChipRow(activeTech: tech, activeMat: mat),
          Expanded(
            child: history.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.invalidate(recommendationHistoryProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(
                      onUpload: () => context.go(AppRoutes.upload));
                }
                final list = ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _HistoryItemCard(
                    item: items[i],
                    onTap: () => context.push(
                      AppRoutes.recommendResult,
                      extra: items[i],
                    ),
                  ),
                );
                // RefreshIndicator intercepts pointer events on web.
                if (kIsWeb) return list;
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(recommendationHistoryProvider),
                  child: list,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// Filter chip row
// ═════════════════════════════════════════════════════════════════════════════

class _FilterChipRow extends ConsumerWidget {
  const _FilterChipRow({required this.activeTech, required this.activeMat});

  final String? activeTech;
  final String? activeMat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAll = activeTech == null && activeMat == null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All
            _Chip(
              label: 'All',
              selected: isAll,
              onTap: () {
                ref.read(historyTechnologyFilterProvider.notifier).state =
                    null;
                ref.read(historyMaterialFilterProvider.notifier).state = null;
              },
            ),
            const SizedBox(width: 8),

            // Divider between All and tech chips
            Container(width: 1, height: 20, color: AppColors.borderLight),
            const SizedBox(width: 8),

            // Technology chips
            for (final t in _techFilters) ...[
              _Chip(
                label: t,
                selected: activeTech == t,
                onTap: () {
                  final next = activeTech == t ? null : t;
                  ref
                      .read(historyTechnologyFilterProvider.notifier)
                      .state = next;
                },
              ),
              const SizedBox(width: 8),
            ],

            // Divider between tech and material chips
            Container(width: 1, height: 20, color: AppColors.borderLight),
            const SizedBox(width: 8),

            // Material chips
            for (final entry in _materialFilterMap.entries) ...[
              _Chip(
                label: entry.key,
                selected: activeMat == entry.value,
                onTap: () {
                  final next = activeMat == entry.value ? null : entry.value;
                  ref
                      .read(historyMaterialFilterProvider.notifier)
                      .state = next;
                },
              ),
              if (entry.key != _materialFilterMap.keys.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFEFEFF4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// History item card
// ═════════════════════════════════════════════════════════════════════════════

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item, required this.onTap});

  final RecommendationResult item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tech = item.technology ?? '—';
    final mat = item.material ?? '—';
    final tier = item.confidenceTier ?? 'low';
    final overallConf = item.technologyConfidence != null &&
            item.materialConfidence != null
        ? (item.technologyConfidence! + item.materialConfidence!) / 2
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row: title + rating ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$tech · $mat',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  item.userRating != null
                      ? _StarDisplay(rating: item.userRating!)
                      : const Text(
                          'Not rated',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Chips ────────────────────────────────────────────────────
              Row(
                children: [
                  _TechChip(label: tech),
                  const SizedBox(width: 6),
                  _MatChip(label: mat),
                ],
              ),
              const SizedBox(height: 10),

              // ── Confidence bar ───────────────────────────────────────────
              if (overallConf != null)
                _ConfidenceRow(confidence: overallConf, tier: tier)
              else
                _TierBadge(tier: tier),

              // ── Scores ───────────────────────────────────────────────────
              if (item.costScore != null &&
                  item.qualityScore != null &&
                  item.speedScore != null) ...[
                const SizedBox(height: 12),
                _ScoreRow(
                  costScore: item.costScore!,
                  qualityScore: item.qualityScore!,
                  speedScore: item.speedScore!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    if (diff < 7) return '${diff}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TechChip extends StatelessWidget {
  const _TechChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _MatChip extends StatelessWidget {
  const _MatChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.confidence, required this.tier});
  final double confidence;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final color = switch (tier) {
      'high' => AppColors.success,
      'medium' => AppColors.warning,
      _ => AppColors.error,
    };
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFEFEFF4),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pct% ${_tierLabel(tier)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _tierLabel(String tier) => switch (tier) {
        'high' => 'high',
        'medium' => 'moderate',
        _ => 'low',
      };
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final color = switch (tier) {
      'high' => AppColors.success,
      'medium' => AppColors.warning,
      _ => AppColors.error,
    };
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '${tier[0].toUpperCase()}${tier.substring(1)} confidence',
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.costScore,
    required this.qualityScore,
    required this.speedScore,
  });

  final int costScore;
  final int qualityScore;
  final int speedScore;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ScoreCell(score: costScore, label: 'Cost'),
        _ScoreCell(score: qualityScore, label: 'Quality'),
        _ScoreCell(score: speedScore, label: 'Speed'),
      ],
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.score, required this.label});
  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppColors.success
        : score >= 50
            ? AppColors.warning
            : AppColors.error;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: const Color(0xFFF59E0B),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Empty state
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onUpload});
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No recommendations yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a file to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload a file'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Error view
// ═════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
