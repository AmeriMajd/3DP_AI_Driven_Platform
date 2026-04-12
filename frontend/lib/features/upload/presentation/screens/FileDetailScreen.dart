import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/stl_file.dart';
import '../providers/upload_provider.dart';
import '../widgets/model_3d_viewer.dart';
import '../widgets/geometry_info_card.dart';
import '../widgets/model_status_banner.dart';

class FileDetailScreen extends ConsumerStatefulWidget {
  final String fileId;
  const FileDetailScreen({required this.fileId, super.key});

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final files = ref.read(uploadProvider).files;
      final file = files.cast<STLFile?>().firstWhere(
        (f) => f?.id == widget.fileId,
        orElse: () => null,
      );
      if (file != null && !file.isReady && !file.isError) {
        ref.read(uploadProvider.notifier).startPolling(widget.fileId);
      }
    });
  }

  @override
  void dispose() {
    // Le polling est arrêté automatiquement par le notifier si status = ready/error.
    // Si l'utilisateur quitte manuellement, on stoppe explicitement.
    ref.read(uploadProvider.notifier).stopPolling();
    super.dispose();
  }

  // ── Confirm delete dialog ─────────────────────────────────────────────────
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
      await ref.read(uploadProvider.notifier).deleteFile(id: file.id);
      if (context.mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Lookup sécurisé — le fichier peut ne plus exister après suppression ──
    final files = ref.watch(uploadProvider).files;
    final STLFile? file = files.cast<STLFile?>().firstWhere(
      (f) => f?.id == widget.fileId,
      orElse: () => null,
    );

    if (file == null) {
      // Fichier supprimé ou introuvable
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
            color: Color(0xFF1C1C1E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            onPressed: () => _confirmDelete(context, file),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1 : 3D Viewer
            Model3DViewer(file: file),
            const SizedBox(height: 12),

            // Section 2 : Status Banner
            ModelStatusBanner(status: file.status),
            if (file.isError) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(uploadProvider.notifier)
                      .reprocessFile(id: file.id),
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
            const SizedBox(height: 12),

            // Section 3 : Geometry Info + Warnings
            GeometryInfoCard(file: file),
            const SizedBox(height: 16),

            // Section 4 : CTA — visible seulement si ready
            if (file.isReady)
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(
                    '${AppRoutes.recommendForm}?fileId=${file.id}',
                  ),
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Continue to AI Analysis',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}
