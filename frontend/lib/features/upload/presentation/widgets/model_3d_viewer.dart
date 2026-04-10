import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:dio/dio.dart';

import '../../domain/stl_file.dart';
import 'package:frontend/shared/services/dio_client.dart';

/// Record contenant les angles de rotation Rx/Ry/Rz en degrés.
typedef OrientationAngles = ({double rx, double ry, double rz});

class Model3DViewer extends StatefulWidget {
  final STLFile file;

  /// Si non null, applique cette rotation au modèle 3D dans le viewer.
  /// Format : ({ rx: 90.0, ry: 0.0, rz: 0.0 })
  final OrientationAngles? orientationAngles;

  /// Hauteur fixe optionnelle. Si null, prend toute la hauteur disponible.
  final double? height;

  const Model3DViewer({
    required this.file,
    this.orientationAngles,
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
    // Recharger si le fichier change ou si le statut passe à ready
    if (oldWidget.file.id != widget.file.id ||
        oldWidget.file.status != widget.file.status) {
      _glbDataUrlFuture = _loadGlbAsDataUrl();
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
    // Sans height → SizedBox.expand pour remplir Expanded/Stack parent
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

        // Convertit les angles en format attendu par model-viewer :
        // "Xdeg Ydeg Zdeg" — correspond à orbit / orientation attribute
        final angles = widget.orientationAngles;
        final orientationStr = angles != null
            ? '${angles.rx}deg ${angles.ry}deg ${angles.rz}deg'
            : null;

        return ModelViewer(
          src: src,
          alt: widget.file.originalFilename,
          ar: false,
          autoRotate: true,
          cameraControls: true,
          backgroundColor: const Color(0xFF1A1A2E),
          // Applique la rotation si une orientation est sélectionnée
          orientation: orientationStr,
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

    // Cas 2 : glbUrl est un chemin relatif — le télécharger via Dio avec le token Bearer.
    // On préfère le chemin fourni par le backend, sinon on reconstruit l'endpoint standard.
    final endpoint = (glbUrl != null && glbUrl.isNotEmpty)
        ? glbUrl
        : '/stl/${widget.file.id}/glb';

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