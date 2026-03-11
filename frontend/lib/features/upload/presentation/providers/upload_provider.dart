import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stl_repository.dart';
import '../../data/stl_repository_mock.dart';
import '../../data/stl_repository_impl.dart';
import '../../domain/stl_file.dart';
import 'upload_state.dart';

final stlRepositoryProvider = Provider<StlRepository>((ref) {
  return StlRepositoryMock(); // ← changer en StlRepositoryImpl() pour le vrai backend
});

final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  return UploadNotifier(ref.read(stlRepositoryProvider));
});

class UploadNotifier extends StateNotifier<UploadState> {
  final StlRepository _repo;

  UploadNotifier(this._repo) : super(const UploadState());

  /// Sélectionner un fichier localement — pas encore uploadé
  void selectFile({required String filename, required int fileSize}) {
    final ext = filename.split('.').last.toLowerCase();
    if (!['stl', '3mf'].contains(ext)) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Only STL and 3MF files are allowed',
      );
      return;
    }
    if (fileSize > 50 * 1024 * 1024) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'File exceeds 50 MB limit',
      );
      return;
    }
    state = state.copyWith(
      status: UploadStatus.initial,
      selectedFileName: filename,
      selectedFileSize: fileSize,
    );
  }

  /// POST /stl/upload
  Future<void> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
  }) async {
    state = state.copyWith(status: UploadStatus.uploading);
    try {
      final file = await _repo.uploadFile(
        filePath: filePath,
        filename: filename,
        fileSize: fileSize,
      );
      // Ajouter le nouveau fichier en tête de liste
      final updatedFiles = [file, ...state.files];
      state = state.copyWith(
        status: UploadStatus.success,
        files: updatedFiles,
        successMessage: '${file.originalFilename} uploaded successfully',
        selectedFileName: null,
        selectedFileSize: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// GET /stl/
  Future<void> loadFiles() async {
    state = state.copyWith(isLoadingFiles: true);
    try {
      final files = await _repo.getFiles();
      state = state.copyWith(
        files: files,
        isLoadingFiles: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingFiles: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// DELETE /stl/{id}
  Future<void> deleteFile({required String id}) async {
    try {
      await _repo.deleteFile(id: id);
      final updatedFiles =
          state.files.where((f) => (f as STLFile).id != id).toList();
      state = state.copyWith(files: updatedFiles);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void reset() => state = const UploadState();
}