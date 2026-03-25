enum UploadStatus { initial, uploading, success, error }

class UploadState {
  final UploadStatus status;
  final List<dynamic> files;
  final bool isLoadingFiles;
  final String? selectedFileName;
  final int? selectedFileSize;
  final String? errorMessage;
  final String? successMessage;
  final String? pollingFileId;

  const UploadState({
    this.status = UploadStatus.initial,
    this.files = const [],
    this.isLoadingFiles = false,
    this.selectedFileName,
    this.selectedFileSize,
    this.errorMessage,
    this.successMessage,
    this.pollingFileId,
  });

  bool get isUploading => status == UploadStatus.uploading;
  bool get hasFileSelected => selectedFileName != null;
  bool get isPolling => pollingFileId != null; 

  UploadState copyWith({
    UploadStatus? status,
    List<dynamic>? files,
    bool? isLoadingFiles,
    String? selectedFileName,
    int? selectedFileSize,
    String? errorMessage,
    String? successMessage,
    String? pollingFileId, 
  }) {
    return UploadState(
      status: status ?? this.status,
      files: files ?? this.files,
      isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      selectedFileName: selectedFileName ?? this.selectedFileName,
      selectedFileSize: selectedFileSize ?? this.selectedFileSize,
      errorMessage: errorMessage ?? this.errorMessage,  
      successMessage: successMessage ?? this.successMessage,
      pollingFileId: pollingFileId ?? this.pollingFileId, 
    );
  }
}