class STLFile {
  final String id;
  final String originalFilename;
  final int fileSizeBytes;
  final String status; // 'uploaded' | 'analyzing' | 'ready' | 'error'
  final DateTime createdAt;

  STLFile({
    required this.id,
    required this.originalFilename,
    required this.fileSizeBytes,
    required this.status,
    required this.createdAt,
  });

  factory STLFile.fromJson(Map<String, dynamic> json) => STLFile(
    id: json['id'],
    originalFilename: json['original_filename'],
    fileSizeBytes: json['file_size_bytes'],
    status: json['status'],
    createdAt: DateTime.parse(json['created_at']),
  );

  String get formattedSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get fileExtension => originalFilename.split('.').last.toUpperCase();

  bool get isReady => status == 'ready';
  bool get isAnalyzing => status == 'analyzing';
  bool get isError => status == 'error';
}