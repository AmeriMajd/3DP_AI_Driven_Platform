import 'dart:typed_data';

import '../domain/stl_file.dart';
import '../domain/orientation_result.dart';
import 'stl_repository.dart';

class StlRepositoryMock implements StlRepository {
  final Map<String, int> _pollCount = {};

  final List<STLFile> _files = [
    STLFile(
      id: 'mock-001',
      originalFilename: 'bracket_v2.stl',
      fileSizeBytes: 2400000,
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      glbUrl: 'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
      volumeCm3: 26.4,
      surfaceAreaCm2: 48.2,
      bboxXMm: 42.0,
      bboxYMm: 30.0,
      bboxZMm: 20.0,
      triangleCount: 12480,
      hasOverhangs: 'yes',
      hasThinWalls: 'no',
      overhangRatio: 0.31,
      maxOverhangAngle: 52.4,
      minWallThicknessMm: 1.2,
      avgWallThicknessMm: 2.8,
      complexityIndex: 1.82,
      aspectRatio: 2.1,
      isWatertight: true,
      shellCount: 1,
      comOffsetRatio: 0.08,
      flatBaseAreaMm2: 420.0,
    ),
    STLFile(
      id: 'mock-002',
      originalFilename: 'housing_final1.3mf',
      fileSizeBytes: 850000,
      status: 'uploaded',
      createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
    ),
  ];

  @override
  Future<STLFile> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
    Uint8List? fileBytes,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    final ext = filename.split('.').last.toLowerCase();
    if (!['stl', '3mf'].contains(ext)) {
      throw Exception('Only STL and 3MF files are allowed');
    }
    if (fileSize > 50 * 1024 * 1024) {
      throw Exception('File exceeds 50 MB limit');
    }
    final newFile = STLFile(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      originalFilename: filename,
      fileSizeBytes: fileSize,
      status: 'uploaded',
      createdAt: DateTime.now(),
    );
    _files.insert(0, newFile);
    return newFile;
  }

  @override
  Future<List<STLFile>> getFiles() async {
    await Future.delayed(const Duration(seconds: 1));
    return List.from(_files);
  }

  @override
  Future<STLFile> getFile({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _files.indexWhere((f) => f.id == id);
    if (index == -1) throw Exception('File not found');

    _pollCount[id] = (_pollCount[id] ?? 0) + 1;
    final ticks = _pollCount[id]!;
    final file = _files[index];

    String newStatus;
    if (ticks <= 2) {
      newStatus = 'uploaded';
    } else if (ticks <= 4) {
      newStatus = 'analyzing';
    } else {
      newStatus = 'ready';
    }

    final isReady = newStatus == 'ready';

    final updated = STLFile(
      id: file.id,
      originalFilename: file.originalFilename,
      fileSizeBytes: file.fileSizeBytes,
      status: newStatus,
      createdAt: file.createdAt,
      glbUrl: isReady
          ? 'https://modelviewer.dev/shared-assets/models/Astronaut.glb'
          : null,
      volumeCm3: isReady ? 18.7 : null,
      surfaceAreaCm2: isReady ? 34.5 : null,
      bboxXMm: isReady ? 55.0 : null,
      bboxYMm: isReady ? 40.0 : null,
      bboxZMm: isReady ? 25.0 : null,
      triangleCount: isReady ? 8960 : null,
      hasOverhangs: isReady ? 'yes' : null,
      hasThinWalls: isReady ? 'no' : null,
      overhangRatio: isReady ? 0.28 : null,
      maxOverhangAngle: isReady ? 47.2 : null,
      minWallThicknessMm: isReady ? 1.5 : null,
      avgWallThicknessMm: isReady ? 3.1 : null,
      complexityIndex: isReady ? 1.64 : null,
      aspectRatio: isReady ? 2.2 : null,
      isWatertight: isReady ? true : null,
      shellCount: isReady ? 1 : null,
      comOffsetRatio: isReady ? 0.05 : null,
      flatBaseAreaMm2: isReady ? 380.0 : null,
    );

    _files[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteFile({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _files.removeWhere((f) => f.id == id);
  }

  /// GET /stl/{id}/orientation — simulé
  /// Retourne 3 orientations réalistes après un délai.
  @override
  Future<List<OrientationResult>> getOrientations({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final file = _files.firstWhere(
      (f) => f.id == id,
      orElse: () => throw Exception('File not found'),
    );

    if (file.status != 'ready') {
      throw Exception('Geometry analysis not complete yet');
    }

    return [
      const OrientationResult(
        rank: 1,
        rxDeg: 0.0,
        ryDeg: 0.0,
        rzDeg: 0.0,
        score: 0.88,
        overhangReductionPct: 34.0,
        printHeightMm: 20.0,
      ),
      const OrientationResult(
        rank: 2,
        rxDeg: 90.0,
        ryDeg: 0.0,
        rzDeg: 0.0,
        score: 0.74,
        overhangReductionPct: 18.0,
        printHeightMm: 42.0,
      ),
      const OrientationResult(
        rank: 3,
        rxDeg: 0.0,
        ryDeg: 90.0,
        rzDeg: 0.0,
        score: 0.61,
        overhangReductionPct: 8.0,
        printHeightMm: 30.0,
      ),
    ];
  }
}