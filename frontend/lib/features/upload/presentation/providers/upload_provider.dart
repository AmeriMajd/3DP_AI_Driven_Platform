import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stl_repository.dart';
import '../../data/stl_repository_impl.dart';
import '../../domain/stl_file.dart';
import 'upload_state.dart';

final stlRepositoryProvider = Provider<StlRepository>((ref) {
  return StlRepositoryImpl();
});

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((
  ref,
) {
  return UploadNotifier(ref.read(stlRepositoryProvider));
});

class UploadNotifier extends StateNotifier<UploadState> {
  final StlRepository _repo;
  Timer? _pollingTimer;
  static const _pollInterval = Duration(seconds: 2);
  static const _maxPollAttempts = 150;
  static const _staleUploadedThreshold = Duration(minutes: 10);

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
    Uint8List? fileBytes,
  }) async {
    state = state.copyWith(status: UploadStatus.uploading);
    try {
      final file = await _repo.uploadFile(
        filePath: filePath,
        filename: filename,
        fileSize: fileSize,
        fileBytes: fileBytes,
      );
      final updatedFiles = [file, ...state.files];
      state = state.copyWith(
        status: UploadStatus.success,
        files: updatedFiles,
        successMessage: '${file.originalFilename} uploaded successfully',
      );
      startPolling(file.id);
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
      state = state.copyWith(files: files, isLoadingFiles: false);
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
      if (state.pollingFileId == id) stopPolling();
      await _repo.deleteFile(id: id);
      final updatedFiles = state.files.where((f) => f.id != id).toList();
      state = state.copyWith(files: updatedFiles);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void startPolling(String fileId) {
    stopPolling();
    state = state.copyWith(pollingFileId: fileId);

    var pollAttempts = 0;

    _pollingTimer = Timer.periodic(_pollInterval, (_) async {
      pollAttempts++;

      try {
        final updatedFile = await _repo.getFile(id: fileId);
        _replaceFile(updatedFile);

        final isStaleUploaded =
            updatedFile.status == 'uploaded' &&
            DateTime.now().difference(updatedFile.createdAt) >
                _staleUploadedThreshold;

        if (updatedFile.status == 'ready' || updatedFile.status == 'error') {
          stopPolling();
        } else if (isStaleUploaded) {
          _failPolling('This file is stuck in uploaded status. Please re-upload it.');
          stopPolling();
        } else if (pollAttempts >= _maxPollAttempts) {
          _failPolling('File processing timed out. Status: ${updatedFile.status}');
          stopPolling();
        }
      } catch (e) {
        if (pollAttempts >= _maxPollAttempts) {
          _failPolling('Network error during processing. Please check the file status manually.');
          stopPolling();
        }
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    state = state.copyWith(clearPollingFileId: true);
  }

  void reset() {
    state = UploadState(files: state.files, pollingFileId: state.pollingFileId);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _replaceFile(STLFile updatedFile) {
    final updatedFiles = state.files
        .map((file) => file.id == updatedFile.id ? updatedFile : file)
        .toList();
    state = state.copyWith(files: updatedFiles);
  }

  void _failPolling(String message) {
    state = state.copyWith(
      status: UploadStatus.error,
      errorMessage: message,
    );
  }
}
