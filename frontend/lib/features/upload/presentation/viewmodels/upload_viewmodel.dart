import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/stl_repository.dart';
import '../../domain/stl_file.dart';
import '../../domain/upload_state.dart';

class UploadViewModel extends StateNotifier<UploadState> {
  final StlRepository _repo;

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

  // HTTP polling removed — STL pipeline pushes `stl.status` events over WS,
  // and FileDetailScreen calls `refreshFile(id)` on each event. We keep
  // start/stopPolling as a no-op state marker so existing callers compile
  // and the UI knows which file is currently transitioning.
  void startPolling(String fileId) {
    state = state.copyWith(pollingFileId: fileId);
  }

  void stopPolling() {
    state = state.copyWith(clearPollingFileId: true);
  }

  /// One-shot refresh — called by the WS listener on `stl.status` events.
  Future<void> refreshFile(String fileId) async {
    try {
      final updated = await _repo.getFile(id: fileId);
      _replaceFile(updated);
      if (updated.status == 'ready' || updated.status == 'error') {
        if (state.pollingFileId == fileId) stopPolling();
      }
    } catch (_) {
      // Best-effort: ignore. Polling fallback still active.
    }
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

}
