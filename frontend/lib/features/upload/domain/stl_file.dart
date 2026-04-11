class STLFile {
  final String id;
  final String originalFilename;
  final int fileSizeBytes;
  final String status; // 'uploaded' | 'analyzing' | 'ready' | 'error'
  final DateTime createdAt;
  final String? glbUrl; // URL vers l'endpoint GET /stl/{id}/glb
  // geometry — nullable jusqu'à status = ready
  final double? volumeCm3;
  final double? surfaceAreaCm2;
  final double? bboxXMm;
  final double? bboxYMm;
  final double? bboxZMm;
  final int? triangleCount;
  final String? hasOverhangs; // 'yes' | 'no' | 'unknown'
  final String? hasThinWalls; // 'yes' | 'no' | 'unknown'


   // Advanced geometry features (Sprint 2B) ──
  final double? overhangRatio;       // 0.0–1.0
  final double? maxOverhangAngle;    // degrees
  final double? minWallThicknessMm;
  final double? avgWallThicknessMm;
  final double? complexityIndex;     // surface_area / volume
  final double? aspectRatio;         // max(bbox) / min(bbox)
  final bool? isWatertight;
  final int? shellCount;
  final double? comOffsetRatio;
  final double? flatBaseAreaMm2;


  STLFile({
    required this.id,
    required this.originalFilename,
    required this.fileSizeBytes,
    required this.status,
    required this.createdAt,
    this.glbUrl,
    this.volumeCm3,
    this.surfaceAreaCm2,
    this.bboxXMm,
    this.bboxYMm,
    this.bboxZMm,
    this.triangleCount,
    this.hasOverhangs,
    this.hasThinWalls,
    this.overhangRatio,
    this.maxOverhangAngle,
    this.minWallThicknessMm,
    this.avgWallThicknessMm,
    this.complexityIndex,
    this.aspectRatio,
    this.isWatertight,
    this.shellCount,
    this.comOffsetRatio,
    this.flatBaseAreaMm2,

  });

  static String? _normalizeFlag(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'yes' : 'no';

    final lower = value.toString().toLowerCase();
    if (lower == 'yes' || lower == 'no' || lower == 'unknown') {
      return lower;
    }
    return null;
  }

  factory STLFile.fromJson(Map<String, dynamic> json) => STLFile(
    id: json['id'].toString(),
    originalFilename: (json['original_filename'] ?? '').toString(),
    fileSizeBytes: (json['file_size_bytes'] as num).toInt(),
    status: (json['status'] ?? '').toString(),
    createdAt: DateTime.parse(json['created_at']),
    glbUrl: json['glb_url']?.toString(),
    volumeCm3: json['volume_cm3']?.toDouble(),
    surfaceAreaCm2: json['surface_area_cm2']?.toDouble(),
    bboxXMm: json['bbox_x_mm']?.toDouble(),
    bboxYMm: json['bbox_y_mm']?.toDouble(),
    bboxZMm: json['bbox_z_mm']?.toDouble(),
    triangleCount: (json['triangle_count'] as num?)?.toInt(),
    hasOverhangs: _normalizeFlag(json['has_overhangs']),
    hasThinWalls: _normalizeFlag(json['has_thin_walls']),
    // advanced
    overhangRatio: json['overhang_ratio']?.toDouble(),
    maxOverhangAngle: json['max_overhang_angle']?.toDouble(),
    minWallThicknessMm: json['min_wall_thickness_mm']?.toDouble(),
    avgWallThicknessMm: json['avg_wall_thickness_mm']?.toDouble(),
    complexityIndex: json['complexity_index']?.toDouble(),
    aspectRatio: json['aspect_ratio']?.toDouble(),
    isWatertight: json['is_watertight'] as bool?,
    shellCount: (json['shell_count'] as num?)?.toInt(),
    comOffsetRatio: json['com_offset_ratio']?.toDouble(),
    flatBaseAreaMm2: json['flat_base_area_mm2']?.toDouble(),
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
