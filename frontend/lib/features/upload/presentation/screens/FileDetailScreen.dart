import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/stl_file.dart';
import '../../domain/orientation_result.dart';
import '../providers/upload_providers.dart';
import '../widgets/model_3d_viewer.dart';
import '../widgets/geometry_details_card.dart';
import '../widgets/model_status_banner.dart';
import '../widgets/orientation_card.dart';

class FileDetailScreen extends ConsumerStatefulWidget {
  final String fileId;
  const FileDetailScreen({required this.fileId, super.key});

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 0-indexed slot of the orientation the user tapped in the Orientation tab.
  // Converted to a 1-indexed rank when passed to Model3DViewer.
  int? _selectedOrientationIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final files = ref.read(uploadViewModelProvider).files;
      final file = _findFile(files);
      if (file == null) return;

      if (!file.isReady && !file.isError) {
        // Fichier encore en cours de traitement — lancer le polling.
        // orientationsProvider se rechargera automatiquement quand
        // uploadViewModelProvider mettra status à 'ready'.
        ref.read(uploadViewModelProvider.notifier).startPolling(widget.fileId);
      }
      // Si déjà ready : orientationsProvider(fileId) se déclenche
      // automatiquement au premier watch dans le build.
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    ref.read(uploadViewModelProvider.notifier).stopPolling();
    super.dispose();
  }

  STLFile? _findFile(List<STLFile> files) => files.cast<STLFile?>().firstWhere(
    (f) => f?.id == widget.fileId,
    orElse: () => null,
  );

  Future<void> _confirmDelete(BuildContext context, STLFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Model',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        content: Text(
          'Delete "${file.originalFilename}" permanently?\n'
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(uploadViewModelProvider.notifier).deleteFile(id: file.id);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(uploadViewModelProvider).files;
    final STLFile? file = _findFile(files);

    if (file == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text(
            'Model not found',
            style: TextStyle(color: Color(0xFF8E8E93)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: AppColors.primary,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.upload),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              file.originalFilename,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${file.formattedSize} · ${file.fileExtension}'
              '${file.triangleCount != null ? ' · ${_fmtInt(file.triangleCount!)} triangles' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          if (file.isReady)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.40)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        letterSpacing: 0.5,
                      )),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Color(0xFFEF4444)),
            onPressed: () => _confirmDelete(context, file),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _PillTabBar(
              controller: _tabController,
              tabs: const [
                (icon: Icons.visibility_outlined, label: '3D Preview'),
                (icon: Icons.view_in_ar_rounded,  label: 'Geometry'),
                (icon: Icons.rotate_90_degrees_cw_outlined,
                 label: 'Orientation'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: 3D Preview ──────────────────────────────────────────
          _PreviewTab(
            file: file,
            // rank is 1-indexed; _selectedOrientationIndex is 0-indexed
            selectedRank: _selectedOrientationIndex != null
                ? _selectedOrientationIndex! + 1
                : null,
            selectedOrientationIndex: _selectedOrientationIndex,
          ),

          // ── Tab 2: Geometry Analysis ───────────────────────────────────
          _GeometryTab(
            file: file,
            onRetry: () =>
                ref.read(uploadViewModelProvider.notifier).reprocessFile(id: file.id),
          ),

          // ── Tab 3: Orientation ─────────────────────────────────────────
          // orientationsProvider gère le cache, loading et erreurs.
          Consumer(
            builder: (context, ref, _) {
              final orientationsAsync = ref.watch(
                orientationsProvider(widget.fileId),
              );
              return orientationsAsync.when(
                data: (orientations) => _OrientationTab(
                  file: file,
                  orientations: orientations,
                  isLoading: false,
                  selectedOrientationIndex: _selectedOrientationIndex,
                  onSelect: (index, result) {
                    setState(() {
                      _selectedOrientationIndex = index;
                    });
                  },
                ),
                loading: () => _OrientationTab(
                  file: file,
                  orientations: const [],
                  isLoading: true,
                  onSelect: (_, _) {},
                ),
                error: (e, _) => _OrientationTab(
                  file: file,
                  orientations: const [],
                  isLoading: false,
                  onSelect: (_, _) {},
                ),
              );
            },
          ),
        ],
      ),
      // ── CTA Flottant ──────────────────────────────────────────────────
      bottomNavigationBar: file.isReady
          ? _BottomCTA(
              file: file,
              selectedOrientationIndex: _selectedOrientationIndex,
            )
          : null,
    );
  }
}

// ── Tab 1: 3D Preview ──────────────────────────────────────────────────────────
class _PreviewTab extends StatelessWidget {
  final STLFile file;
  /// 1-indexed rank of the selected orientation (null = default GLB, no rotation).
  final int? selectedRank;
  /// 0-indexed for the badge label — derived from selectedRank by the parent.
  final int? selectedOrientationIndex;

  const _PreviewTab({
    required this.file,
    this.selectedRank,
    this.selectedOrientationIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viewer occupe toute la hauteur et largeur disponibles
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.expand(
                    child: Model3DViewer(
                      file: file,
                      selectedRank: selectedRank,
                    ),
                  ),
                ),
                // Badge flottant si une orientation est sélectionnée
                if (selectedRank != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _OrientationBadge(index: selectedOrientationIndex!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModelStatusBanner(status: file.status),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── Orientation Badge flottant sur le viewer ─────────────────────────────────
class _OrientationBadge extends StatelessWidget {
  final int index;
  const _OrientationBadge({required this.index});

  static const _labels = ['1st', '2nd', '3rd'];
  static const _rankColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final label = _labels[index.clamp(0, 2)];
    final color = _rankColors[index.clamp(0, 2)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rotate_90_degrees_cw_outlined, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$label orientation',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Geometry Analysis ───────────────────────────────────────────────────
class _GeometryTab extends StatelessWidget {
  final STLFile file;
  final VoidCallback onRetry;

  const _GeometryTab({required this.file, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (!file.isReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              const SizedBox(height: 16),
              Text(
                file.isError
                    ? 'Geometry extraction failed'
                    : 'Geometry analysis in progress...',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
              if (file.isError) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Retry Analysis',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GeometryDetailsCard(file: file),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ── Tab 3: Orientation ─────────────────────────────────────────────────────────
class _OrientationTab extends StatelessWidget {
  final STLFile file;
  final List<OrientationResult> orientations;
  final bool isLoading;
  final void Function(int index, OrientationResult result) onSelect;
  final int? selectedOrientationIndex;

  const _OrientationTab({
    required this.file,
    required this.orientations,
    required this.isLoading,
    required this.onSelect,
    this.selectedOrientationIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Fichier pas encore ready — analyse en cours
    if (!file.isReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6366F1)),
              const SizedBox(height: 16),
              Text(
                file.isError
                    ? 'Orientation analysis failed'
                    : 'Computing best orientations...',
                style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    // Fichier ready mais orientations pas encore chargées
    if (isLoading || orientations.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 16),
              Text(
                'Loading orientations...',
                style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          OrientationCard(
            orientations: orientations,
            selectedIndex: selectedOrientationIndex,
            onSelect: onSelect,
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
        ],
      ),
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────────────────
class _BottomCTA extends StatelessWidget {
  final STLFile file;
  final int? selectedOrientationIndex;

  const _BottomCTA({
    required this.file,
    required this.selectedOrientationIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
            color: AppColors.surfaceBackground.withValues(alpha: 0.90),
            border: const Border(
                top: BorderSide(color: AppColors.outlineVariant)),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedOrientationIndex == null) ...[
            const Text(
              'Select an orientation in the Orientation tab to continue',
              style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
            DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '${AppRoutes.recommendForm}?fileId=${file.id}'
                '${selectedOrientationIndex != null ? '&orientation=$selectedOrientationIndex' : ''}',
              ),
              icon: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 18),
              
              label: const Text(
                'Continue to AI Analysis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
      ),
    ),
    );
  }
}

// ── Pill-style tab bar ────────────────────────────────────────────────────────
class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<({IconData icon, String label})> tabs;

  const _PillTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 52,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final selected = controller.index == i;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tab.icon,
                            size: 15,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}