import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:dio/dio.dart';

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
  late Future<String?> _glbDataUrlFuture;

  @override
  void initState() {
    super.initState();
    _glbDataUrlFuture = _loadGlbAsDataUrl();
  }

  @override
  void didUpdateWidget(Model3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.status != widget.file.status) {
      _viewerError = false;
      _glbDataUrlFuture = _loadGlbAsDataUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildViewer(),
      ),
    );
  }

  Widget _buildViewer() {
    // State 3 : erreur viewer
    if (_viewerError) return _buildError();

    // State 1 : pas encore prêt
    if (!widget.file.isReady) {
      return _buildPlaceholder();
    }

    // State 2 : prêt → charger le GLB via Dio pour garder l'auth Bearer.
    return FutureBuilder<String?>(
      future: _glbDataUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder();
        }

        final src = snapshot.data;
        if (src == null || src.isEmpty) {
          return _buildError();
        }

        return ModelViewer(
          src: src,
          alt: widget.file.originalFilename,
          ar: false,
          autoRotate: true,
          cameraControls: true,
          backgroundColor: const Color(0xFF1E1E2E),
        );
      },
    );
    // Note : model_viewer_plus ne lève pas d'exception synchrone —
    // les erreurs de chargement (CORS, 404) sont gérées en interne.
    // Pour capturer les erreurs web, écouter les messages JS si nécessaire.
  }

  Future<String?> _loadGlbAsDataUrl() async {
    if (!widget.file.isReady) {
      return null;
    }

    try {
      final response = await DioClient.instance.get<List<int>>(
        '/stl/${widget.file.id}/glb',
        options: Options(responseType: ResponseType.bytes),
      );

      final raw = response.data;
      if (raw == null || raw.isEmpty) {
        return null;
      }

      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      final base64Data = base64Encode(bytes);
      return 'data:model/gltf-binary;base64,$base64Data';
    } catch (_) {
      return null;
    }
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
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
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
