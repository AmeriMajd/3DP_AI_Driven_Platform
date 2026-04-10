import 'package:dotted_border/dotted_border.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // ← pour kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../providers/upload_provider.dart';
import '../providers/upload_state.dart';
import '../../domain/stl_file.dart';
import 'package:go_router/go_router.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(uploadProvider.notifier).loadFiles();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Sélectionner un fichier ──────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['stl', '3mf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // Sur web path n'existe pas — on utilise kIsWeb pour éviter le crash ──
    // kIsWeb est un booléen Flutter qui vaut true sur web
    if (kIsWeb) {
      _selectedFileBytes = file.bytes;
      _selectedFilePath = null;
    } else {
      _selectedFileBytes = null;
      _selectedFilePath = file.path; // mobile/desktop uniquement
    }
    // Sur web _selectedFilePath reste null → _uploadFile() passe '' à la place
    ref
        .read(uploadProvider.notifier)
        .selectFile(filename: file.name, fileSize: file.size);
  }

  // ── Uploader le fichier sélectionné ─────────────────────────────────────
  Future<void> _uploadFile() async {
    final state = ref.read(uploadProvider);
    if (state.selectedFileName == null) return;

    final filePath = _selectedFilePath ?? '';
    await ref
        .read(uploadProvider.notifier)
        .uploadFile(
          filePath: filePath,
          filename: state.selectedFileName!,
          fileSize: state.selectedFileSize ?? 0,
          fileBytes: _selectedFileBytes,
        );
    _selectedFilePath = null;
    _selectedFileBytes = null;
  }

  // ── Filtrer les fichiers ─────────────────────────────────────────────────
  List<STLFile> _filteredFiles(List<STLFile> files) {
    if (_searchQuery.isEmpty) return files;
    return files
        .where((f) => f.originalFilename.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // ── Temps relatif ────────────────────────────────────────────────────────
  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return 'Uploaded ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Uploaded ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Uploaded ${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showAllFiles(List<STLFile> files) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ← hauteur dynamique
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllFilesSheet(
        files: files,
        timeAgo: _timeAgo,
        onDelete: (id) {
          Navigator.pop(ctx); // ← fermer le sheet
          ref.read(uploadProvider.notifier).deleteFile(id: id);
        },
        onTap: (id) {
          Navigator.pop(ctx);
          context.go('${AppRoutes.upload}/file/$id');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uploadProvider);

    // ── Snackbars ──────────────────────────────────────────────────────────
    ref.listen<UploadState>(uploadProvider, (_, next) {
      if (next.status == UploadStatus.success && next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        ref.read(uploadProvider.notifier).reset();
      }
      if (next.status == UploadStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        ref.read(uploadProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search Bar ─────────────────────────────────────────
                  _buildSearchBar(),
                  const SizedBox(height: 16),

                  // ── Subtitle ───────────────────────────────────────────
                  const Text(
                    'Upload your 3D model file to begin',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Upload Zone ────────────────────────────────────────
                  _buildUploadZone(),
                  const SizedBox(height: 14),

                  // ── Fichier sélectionné ────────────────────────────────
                  if (state.hasFileSelected) ...[
                    _buildSelectedFile(state),
                    const SizedBox(height: 14),
                  ],

                  // ── Liste fichiers ─────────────────────────────────────
                  _buildFileList(state),
                  // éviter Scroll excessif
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search your library...',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ── Upload Zone ──────────────────────────────────────────────────────────
  Widget _buildUploadZone() {
    return DottedBorder(
      color: AppColors.primary.withValues(alpha: 0.4),
      strokeWidth: 1.5,
      dashPattern: const [8, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Icône upload
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.upload_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Drop your file here',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'or click to browse',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Bouton Select file
            SizedBox(
              width: 200,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Select file',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Badges formats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _FormatBadge(label: 'STL'),
                SizedBox(width: 8),
                _FormatBadge(label: '3MF'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fichier sélectionné ──────────────────────────────────────────────────
  Widget _buildSelectedFile(UploadState state) {
    final sizeText = state.selectedFileSize != null
        ? state.selectedFileSize! < 1024 * 1024
              ? '${(state.selectedFileSize! / 1024).toStringAsFixed(1)} KB'
              : '${(state.selectedFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.selectedFileName ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sizeText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => ref.read(uploadProvider.notifier).reset(),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: state.isUploading ? null : _uploadFile,
              icon: state.isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.cloud_upload_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                state.isUploading ? 'Uploading...' : 'Upload File',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.6,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Liste fichiers uploadés ──────────────────────────────────────────────
  Widget _buildFileList(UploadState state) {
    if (state.isLoadingFiles) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final filtered = _filteredFiles(state.files);
    final displayed = filtered.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header + View all ────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Uploaded Models',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.files.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (filtered.length > 3)
              GestureDetector(
                onTap: () => _showAllFiles(filtered),
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Vide ──────────────────────────────────────────────────────────
        if (state.files.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 8),
                Text(
                  'No models uploaded yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        // ── Recherche vide ────────────────────────────────────────────────
        else if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No results for "$_searchQuery"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        // ── Items ─────────────────────────────────────────────────────────
        else
          ...displayed.map(
            (f) => _FileItem(
              file: f,
              timeAgo: _timeAgo(f.createdAt),
              onDelete: () =>
                  ref.read(uploadProvider.notifier).deleteFile(id: f.id),
              onTap: () => context.go('${AppRoutes.upload}/file/${f.id}'),
            ),
          ),

        // ── +X more ───────────────────────────────────────────────────────
        if (filtered.length > 3) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              '+${filtered.length - 3} more — tap View all',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Format Badge ──────────────────────────────────────────────────────────────
class _FormatBadge extends StatelessWidget {
  final String label;
  const _FormatBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ── File Item ─────────────────────────────────────────────────────────────────
class _FileItem extends StatelessWidget {
  final STLFile file;
  final String timeAgo;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _FileItem({
    required this.file,
    required this.timeAgo,
    required this.onDelete,
    required this.onTap,
  });

  Color get _statusColor {
    switch (file.status) {
      case 'ready':
        return AppColors.success;
      case 'analyzing':
        return const Color(0xFFF59E0B);
      case 'error':
        return AppColors.error;
      default:
        return const Color(0xFF8B8BFF);
    }
  }

  String get _statusLabel {
    switch (file.status) {
      case 'ready':
        return 'Ready';
      case 'analyzing':
        return 'Analyzing';
      case 'error':
        return 'Error';
      default:
        return 'Uploaded';
    }
  }

  IconData get _statusIcon {
    switch (file.status) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'analyzing':
        return Icons.hourglass_top_outlined;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.cloud_done_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône fichier
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Nom + temps · taille · type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.originalFilename,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$timeAgo · ${file.formattedSize} · ${file.fileExtension}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, size: 11, color: _statusColor),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Bouton delete
            GestureDetector(
              onTap: () async {
                // ── Confirmation dialog ──────────────────────────────
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Delete Model',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    content: Text(
                      'Delete "${file.originalFilename}" permanently?',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
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
                if (confirm == true) onDelete();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── All Files Bottom Sheet ────────────────────────────────────────────────────
class _AllFilesSheet extends StatelessWidget {
  final List<STLFile> files;
  final String Function(DateTime) timeAgo;
  final void Function(String id) onDelete;
  final void Function(String id) onTap;

  const _AllFilesSheet({
    required this.files,
    required this.timeAgo,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      // Max 80% de la hauteur écran
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'All Models',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${files.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                // Bouton fermer
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Liste scrollable ─────────────────────────────────────────────
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (_, index) {
                final f = files[index];
                return _FileItem(
                  file: f,
                  timeAgo: timeAgo(f.createdAt),
                  onDelete: () => onDelete(f.id),
                  onTap: () => onTap(f.id),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
