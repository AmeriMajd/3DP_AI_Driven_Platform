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
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    // Simuler erreur extension
    final ext = filename.split('.').last.toLowerCase();
    if (!['stl', '3mf'].contains(ext)) {
      throw Exception('Only STL and 3MF files are allowed');
    }

    // Simuler erreur taille
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
  // Future<STLFile> getFile({required String id}) async {
  //   await Future.delayed(const Duration(milliseconds: 500));
  //   return _files.firstWhere(
  //   (f) => f.id == id,
  //   orElse: () => throw Exception('File not found'),
  // );
  // }
 
  Future<STLFile> getFile({required String id}) async {
  await Future.delayed(const Duration(milliseconds: 300));

  final index = _files.indexWhere((f) => f.id == id);
  if (index == -1) throw Exception('File not found');

  // Incrémenter le compteur de ticks pour ce fichier
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

  final updated = STLFile(
    id: file.id,
    originalFilename: file.originalFilename,
    fileSizeBytes: file.fileSizeBytes,
    status: newStatus,
    createdAt: file.createdAt,
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