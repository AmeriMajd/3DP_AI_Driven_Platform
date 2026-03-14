import '../domain/stl_file.dart';
import 'stl_repository.dart';

class StlRepositoryMock implements StlRepository {
  final List<STLFile> _files = [
    STLFile(
      id: 'mock-001',
      originalFilename: 'bracket_v2.stl',
      fileSizeBytes: 2400000,
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    STLFile(
      id: 'mock-002',
      originalFilename: 'housing_final.3mf',
      fileSizeBytes: 850000,
      status: 'uploaded',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    STLFile(
      id: 'mock-002',
      originalFilename: 'housing_final.3mf',
      fileSizeBytes: 850000,
      status: 'uploaded',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    STLFile(
      id: 'mock-002',
      originalFilename: 'housing_final.3mf',
      fileSizeBytes: 850000,
      status: 'uploaded',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
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
  Future<STLFile> getFile({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _files.firstWhere(
    (f) => f.id == id,
    orElse: () => throw Exception('File not found'),
  );
  }

  @override
  Future<void> deleteFile({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _files.removeWhere((f) => f.id == id);
  }
}