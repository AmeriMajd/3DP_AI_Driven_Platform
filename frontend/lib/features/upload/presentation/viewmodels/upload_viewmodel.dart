import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/stl_repository.dart';
import '../../domain/stl_file.dart';
import '../../domain/upload_state.dart';

class UploadViewModel extends StateNotifier<UploadState> {
  final StlRepository _repo;
  Timer? _pollingTimer;

  static const _pollInterval = Duration(seconds: 2);
  static const _maxPollAttempts = 150;
  static const _staleUploadedThreshold = Duration(minutes: 10);

  UploadViewModel(this._repo) : super(const UploadState());

  void selectFile({required String filename, required int fileSize}) {
    final ext = filename.split('.').last.toLowerCase();
    if (!['stl', '3mf'].contains(ext)) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'Only STL and 3MF files are allowed',
        clearSelectedFile: true,
      );
      return;
    }
    if (fileSize > 50 * 1024 * 1024) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: 'File exceeds 50 MB limit',
        clearSelectedFile: true,
      );
      return;
    }
    state = state.copyWith(
      status: UploadStatus.initial,
      selectedFileName: filename,
      selectedFileSize: fileSize,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  Future<void> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
    Uint8List? fileBytes,
  }) async {
    state = state.copyWith(
      status: UploadStatus.uploading,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    try {
      final file = await _repo.uploadFile(
        filePath: filePath,
        filename: filename,
        fileSize: fileSize,
        fileBytes: fileBytes,
      );
      state = state.copyWith(
        status: UploadStatus.success,
        files: [file, ...state.files],
        successMessage: '${file.originalFilename} uploaded successfully',
        clearSelectedFile: true,
      );
      startPolling(file.id);
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

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

  Future<void> deleteFile({required String id}) async {
    try {
      if (state.pollingFileId == id) stopPolling();
      await _repo.deleteFile(id: id);
      state = state.copyWith(
        files: state.files.where((f) => f.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> reprocessFile({required String id}) async {
    try {
      final reprocessed = await _repo.reprocessFile(id: id);
      final updatedFiles = state.files.map((f) {
        return f.id == id ? reprocessed : f;
      }).toList();
      state = state.copyWith(
        files: updatedFiles,
        successMessage: '${reprocessed.originalFilename} reprocessing started',
        status: UploadStatus.success,
      );
      startPolling(id);
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void startPolling(String fileId) {
    stopPolling();
    state = state.copyWith(pollingFileId: fileId);
    var attempts = 0;

    _pollingTimer = Timer.periodic(_pollInterval, (_) async {
      attempts++;
      try {
        final updated = await _repo.getFile(id: fileId);
        _replaceFile(updated);

        final isStale = updated.status == 'uploaded' &&
            DateTime.now().difference(updated.createdAt) >
                _staleUploadedThreshold;

        if (updated.status == 'ready' || updated.status == 'error') {
          stopPolling();
        } else if (isStale) {
          _failPolling('File is stuck in uploaded status. Please re-upload it.');
          stopPolling();
        } else if (attempts >= _maxPollAttempts) {
          _failPolling('Processing timed out. Status: ${updated.status}');
          stopPolling();
        }
      } catch (_) {
        if (attempts >= _maxPollAttempts) {
          _failPolling('Network error during processing. Check the file status manually.');
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
    state = state.copyWith(
      status: UploadStatus.initial,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
  }

  void _replaceFile(STLFile updated) {
    state = state.copyWith(
      files: state.files.map((f) => f.id == updated.id ? updated : f).toList(),
    );
  }

  void _failPolling(String message) {
    state = state.copyWith(
      status: UploadStatus.error,
      errorMessage: message,
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
