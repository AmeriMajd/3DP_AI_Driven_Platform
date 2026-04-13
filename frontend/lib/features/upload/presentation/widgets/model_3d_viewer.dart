import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:dio/dio.dart';

import '../../domain/stl_file.dart';
import 'package:frontend/shared/services/dio_client.dart';

class Model3DViewer extends StatefulWidget {
  final STLFile file;

  /// When non-null, fetches a pre-rotated GLB from the backend
  /// (GET /stl/{id}/glb?rank={selectedRank}) so the model appears in the
  /// optimal print orientation without any client-side angle conversion.
  /// Rank is 1-indexed (1 = best, 2 = second best, 3 = third best).
  final int? selectedRank;

  /// Hauteur fixe optionnelle. Si null, prend toute la hauteur disponible.
  final double? height;

  const Model3DViewer({
    required this.file,
    this.selectedRank,
    this.height,
    super.key,
  });

  @override
  State<Model3DViewer> createState() => _Model3DViewerState();
}

class _Model3DViewerState extends State<Model3DViewer> {
  late Future<String?> _glbDataUrlFuture;

  @override
  void initState() {
    super.initState();
    _glbDataUrlFuture = _loadGlbAsDataUrl();
  }

  @override
  void didUpdateWidget(Model3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when the file changes, its status changes, or the selected
    // orientation rank changes (each rank serves a differently rotated GLB).
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.status != widget.file.status ||
        oldWidget.selectedRank != widget.selectedRank) {
      setState(() {
        _glbDataUrlFuture = _loadGlbAsDataUrl();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: _buildViewer(),
      );
    }
    return SizedBox.expand(child: _buildViewer());
  }

  Widget _buildViewer() {
    if (!widget.file.isReady) return _buildPlaceholder();

    return FutureBuilder<String?>(
      future: _glbDataUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildPlaceholder();
        }
        final src = snapshot.data;
        if (src == null || src.isEmpty) return _buildError();

        return ModelViewer(
          src: src,
          alt: widget.file.originalFilename,
          ar: false,
          autoRotate: true,
          cameraControls: true,
          backgroundColor: const Color(0xFF1A1A2E),
        );
      },
    );
  }

  Future<String?> _loadGlbAsDataUrl() async {
    if (!widget.file.isReady) return null;

    // Cas 1 : glbUrl est une URL directe (mock ou CDN public) — l'utiliser tel quel.
    final glbUrl = widget.file.glbUrl;
    if (glbUrl != null && glbUrl.startsWith('http')) {
      return glbUrl;
    }

    // Build endpoint. When a rank is selected, append ?rank= so the backend
    // returns a GLB with the rotation baked into the mesh vertices — this
    // avoids all Euler-angle convention and Y-up/Z-up coordinate mismatches.
    final base = (glbUrl != null && glbUrl.isNotEmpty)
        ? glbUrl
        : '/stl/${widget.file.id}/glb';
    final endpoint = widget.selectedRank != null
        ? '$base?rank=${widget.selectedRank}'
        : base;

    try {
      final response = await DioClient.instance.get<List<int>>(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) return null;
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      return 'data:model/gltf-binary;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _RotatingCubeIcon(),
          const SizedBox(height: 14),
          Text(
            'Preparing 3D preview...',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Colors.redAccent, size: 44),
          SizedBox(height: 10),
          Text('Preview unavailable',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
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
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        ),
        child: const Icon(Icons.view_in_ar_rounded,
            color: Colors.white54, size: 32),
      ),
    );
  }
}