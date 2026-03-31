import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../domain/stl_file.dart';
import 'package:frontend/shared/services/dio_client.dart';

class Model3DViewer extends StatefulWidget {
  final STLFile file;
  const Model3DViewer({required this.file, super.key});

  @override
  State<Model3DViewer> createState() => _Model3DViewerState();
}

class _Model3DViewerState extends State<Model3DViewer> {
  bool _viewerError = false;

  @override
  void didUpdateWidget(Model3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset erreur si le fichier change de status
    if (oldWidget.file.status != widget.file.status) {
      setState(() => _viewerError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = DioClient.instance.options.baseUrl;

    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildViewer(baseUrl),
      ),
    );
  }

  Widget _buildViewer(String baseUrl) {
    // State 3 : erreur viewer
    if (_viewerError) return _buildError();

    // State 1 : pas encore prêt
    if (!widget.file.isReady || widget.file.glbUrl == null) {
      return _buildPlaceholder();
    }

    // State 2 : prêt → charger GLB
    final glbUrl = '$baseUrl/stl/${widget.file.id}/glb';

    return ModelViewer(
      src: glbUrl,
      alt: widget.file.originalFilename,
      ar: false,
      autoRotate: true,
      cameraControls: true,
      backgroundColor: const Color(0xFF1E1E2E),
    );
    // Note : model_viewer_plus ne lève pas d'exception synchrone —
    // les erreurs de chargement (CORS, 404) sont gérées en interne.
    // Pour capturer les erreurs web, écouter les messages JS si nécessaire.
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _RotatingCubeIcon(),
          const SizedBox(height: 12),
          Text(
            'Preparing 3D preview...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.red, size: 48),
          SizedBox(height: 8),
          Text(
            'Preview unavailable',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Rotating Cube Icon ────────────────────────────────────────────────────────

class _RotatingCubeIcon extends StatefulWidget {
  const _RotatingCubeIcon();

  @override
  State<_RotatingCubeIcon> createState() => _RotatingCubeIconState();
}

class _RotatingCubeIconState extends State<_RotatingCubeIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.rotate(
        angle: _controller.value * 2 * 3.14159,
        child: child,
      ),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.view_in_ar_rounded,
          color: Colors.white60,
          size: 32,
        ),
      ),
    );
  }
}