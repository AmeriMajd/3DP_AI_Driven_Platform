import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/stl_file.dart';
import '../../domain/orientation_result.dart';
import '../providers/upload_provider.dart';
import '../providers/orientation_provider.dart';
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

  // Orientation sélectionnée par l'utilisateur (index + données)
  int? _selectedOrientationIndex;
  Map<String, dynamic>? _selectedOrientation; // toCardData() d'un OrientationResult

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final files = ref.read(uploadProvider).files;
      final file = _findFile(files);
      if (file == null) return;

      if (!file.isReady && !file.isError) {
        // Fichier encore en cours de traitement — lancer le polling.
        // orientationsProvider se rechargera automatiquement quand
        // uploadProvider mettra status à 'ready'.
        ref.read(uploadProvider.notifier).startPolling(widget.fileId);
      }
      // Si déjà ready : orientationsProvider(fileId) se déclenche
      // automatiquement au premier watch dans le build.
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    ref.read(uploadProvider.notifier).stopPolling();
    super.dispose();
  }

  STLFile? _findFile(List<STLFile> files) =>
      files.cast<STLFile?>().firstWhere(
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
              color: Color(0xFF1C1C1E)),
        ),
        content: Text(
          'Delete "${file.originalFilename}" permanently?\n'
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFFF3B30), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(uploadProvider.notifier).deleteFile(id: file.id);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(uploadProvider).files;
    final STLFile? file = _findFile(files);

    if (file == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(
          child: Text('Model not found',
              style: TextStyle(color: Color(0xFF8E8E93))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF6366F1)),
        title: Text(
          file.originalFilename,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: () => _confirmDelete(context, file),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: const Color(0xFF8E8E93),
              indicatorColor: const Color(0xFF6366F1),
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: '3D Preview'),
                Tab(text: 'Geometry'),
                Tab(text: 'Orientation'),
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
            selectedOrientation: _selectedOrientation,
            selectedOrientationIndex: _selectedOrientationIndex,
          ),

          // ── Tab 2: Geometry Analysis ───────────────────────────────────
          _GeometryTab(file: file),

          // ── Tab 3: Orientation ─────────────────────────────────────────
          // orientationsProvider gère le cache, loading et erreurs.
          Consumer(
            builder: (context, ref, _) {
              final orientationsAsync =
                  ref.watch(orientationsProvider(widget.fileId));
              return orientationsAsync.when(
                data: (orientations) => _OrientationTab(
                  file: file,
                  orientations: orientations,
                  isLoading: false,
                  selectedOrientationIndex: _selectedOrientationIndex,
                  onSelect: (index, result) {
                    setState(() {
                      _selectedOrientationIndex = index;
                      _selectedOrientation = result.toCardData();
                    });
                  },
                ),
                loading: () => _OrientationTab(
                  file: file,
                  orientations: const [],
                  isLoading: true,
                  onSelect: (_, __) {},
                ),
                error: (e, _) => _OrientationTab(
                  file: file,
                  orientations: const [],
                  isLoading: false,
                  onSelect: (_, __) {},
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
  final Map<String, dynamic>? selectedOrientation;
  final int? selectedOrientationIndex;

  const _PreviewTab({
    required this.file,
    this.selectedOrientation,
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
                      orientationAngles: selectedOrientation != null
                          ? (
                              rx: (selectedOrientation!['rx'] as num?)?.toDouble() ?? 0.0,
                              ry: (selectedOrientation!['ry'] as num?)?.toDouble() ?? 0.0,
                              rz: (selectedOrientation!['rz'] as num?)?.toDouble() ?? 0.0,
                            )
                          : null,
                    ),
                  ),
                ),
                // Badge flottant si une orientation est sélectionnée
                if (selectedOrientation != null)
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
          Icon(Icons.rotate_90_degrees_cw_outlined,
              size: 12, color: color),
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
  const _GeometryTab({required this.file});

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
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF8E8E93)),
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
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF8E8E93)),
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
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedOrientationIndex == null) ...[
            const Text(
              'Select an orientation in the Orientation tab to continue',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.go(
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
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}