import 'dart:typed_data';

import '../domain/stl_file.dart';
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
      glbUrl: 'mock', // non-null → viewer se charge
      volumeCm3: 26.4,
      surfaceAreaCm2: 48.2,
      bboxXMm: 42.0,
      bboxYMm: 30.0,
      bboxZMm: 20.0,
      triangleCount: 12480,
      hasOverhangs: 'yes',
      hasThinWalls: 'no',
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

    // tick 1-2 → uploaded, tick 3-4 → analyzing, tick 5+ → ready
    String newStatus;
    if (ticks <= 2) {
      newStatus = 'uploaded';
    } else if (ticks <= 4) {
      newStatus = 'analyzing';
    } else {
      newStatus = 'ready';
    }

    // Remplir les champs geometry + glbUrl uniquement à ready
    final isReady = newStatus == 'ready';

    final updated = STLFile(
      id: file.id,
      originalFilename: file.originalFilename,
      fileSizeBytes: file.fileSizeBytes,
      status: newStatus,
      createdAt: file.createdAt,
      // ← glbUrl non-null dès que ready (le mock n'a pas de vrai fichier)
      glbUrl: isReady ? 'mock' : null,
      volumeCm3: isReady ? 18.7 : null,
      surfaceAreaCm2: isReady ? 34.5 : null,
      bboxXMm: isReady ? 55.0 : null,
      bboxYMm: isReady ? 40.0 : null,
      bboxZMm: isReady ? 25.0 : null,
      triangleCount: isReady ? 8960 : null,
      hasOverhangs: isReady ? 'yes' : null,
      hasThinWalls: isReady ? 'no' : null,
    );

    _files[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteFile({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _files.removeWhere((f) => f.id == id);
  }
}