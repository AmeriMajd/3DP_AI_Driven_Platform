import 'alternative_recommendation.dart';

class RecommendationResult {
  final String id;
  final String stlFileId;

  // Input snapshot
  final int? orientationRank;
  final String intendedUse;
  final String surfaceFinish;
  final bool needsFlexibility;
  final String strengthRequired;
  final String budgetPriority;
  final bool outdoorUse;

  // Result
  final String? technology;
  final String? material;
  final double? technologyConfidence;
  final double? materialConfidence;
  final String? confidenceTier;

  final double? layerHeight;
  final double? layerHeightMin;
  final double? layerHeightMax;
  final int? infillDensity;
  final int? printSpeed;
  final int? wallCount;
  final int? coolingFan;
  final int? supportDensity;

  final int? costScore;
  final int? qualityScore;
  final int? speedScore;

  final bool needsClarification;
  final String? clarificationQuestion;
  final String? clarificationField;

  final AlternativeRecommendation? alternative;

  // Orientation details for the selected orientation rank
  final double? orientationRx;
  final double? orientationRy;
  final double? orientationRz;
  final double? overhangReductionPct;
  final double? orientationPrintHeightMm;

  final int? userRating;
  final DateTime createdAt;

  const RecommendationResult({
    required this.id,
    required this.stlFileId,
    this.orientationRank,
    required this.intendedUse,
    required this.surfaceFinish,
    required this.needsFlexibility,
    required this.strengthRequired,
    required this.budgetPriority,
    required this.outdoorUse,
    this.technology,
    this.material,
    this.technologyConfidence,
    this.materialConfidence,
    this.confidenceTier,
    this.layerHeight,
    this.layerHeightMin,
    this.layerHeightMax,
    this.infillDensity,
    this.printSpeed,
    this.wallCount,
    this.coolingFan,
    this.supportDensity,
    this.costScore,
    this.qualityScore,
    this.speedScore,
    this.needsClarification = false,
    this.clarificationQuestion,
    this.clarificationField,
    this.alternative,
    this.orientationRx,
    this.orientationRy,
    this.orientationRz,
    this.overhangReductionPct,
    this.orientationPrintHeightMm,
    this.userRating,
    required this.createdAt,
  });

  RecommendationResult copyWith({
    String? technology,
    String? material,
    double? layerHeight,
    int? infillDensity,
    int? printSpeed,
    int? wallCount,
    int? coolingFan,
    int? supportDensity,
    int? userRating,
  }) {
    return RecommendationResult(
      id: id,
      stlFileId: stlFileId,
      orientationRank: orientationRank,
      intendedUse: intendedUse,
      surfaceFinish: surfaceFinish,
      needsFlexibility: needsFlexibility,
      strengthRequired: strengthRequired,
      budgetPriority: budgetPriority,
      outdoorUse: outdoorUse,
      technology: technology ?? this.technology,
      material: material ?? this.material,
      technologyConfidence: technologyConfidence,
      materialConfidence: materialConfidence,
      confidenceTier: confidenceTier,
      layerHeight: layerHeight ?? this.layerHeight,
      layerHeightMin: layerHeightMin,
      layerHeightMax: layerHeightMax,
      infillDensity: infillDensity ?? this.infillDensity,
      printSpeed: printSpeed ?? this.printSpeed,
      wallCount: wallCount ?? this.wallCount,
      coolingFan: coolingFan ?? this.coolingFan,
      supportDensity: supportDensity ?? this.supportDensity,
      costScore: costScore,
      qualityScore: qualityScore,
      speedScore: speedScore,
      needsClarification: needsClarification,
      clarificationQuestion: clarificationQuestion,
      clarificationField: clarificationField,
      alternative: alternative,
      orientationRx: orientationRx,
      orientationRy: orientationRy,
      orientationRz: orientationRz,
      overhangReductionPct: overhangReductionPct,
      orientationPrintHeightMm: orientationPrintHeightMm,
      userRating: userRating ?? this.userRating,
      createdAt: createdAt,
    );
  }

  factory RecommendationResult.fromJson(Map<String, dynamic> json) {
    AlternativeRecommendation? alt;
    final altData = json['alternative'];
    if (altData != null && altData is Map<String, dynamic>) {
      alt = AlternativeRecommendation.fromJson(altData);
    }

    return RecommendationResult(
      id: json['id'].toString(),
      stlFileId: json['stl_file_id'].toString(),
      orientationRank: json['orientation_rank'] as int?,
      intendedUse: json['intended_use'] as String,
      surfaceFinish: json['surface_finish'] as String,
      needsFlexibility: json['needs_flexibility'] as bool,
      strengthRequired: json['strength_required'] as String,
      budgetPriority: json['budget_priority'] as String,
      outdoorUse: json['outdoor_use'] as bool,
      technology: json['technology'] as String?,
      material: json['material'] as String?,
      technologyConfidence: (json['technology_confidence'] as num?)?.toDouble(),
      materialConfidence: (json['material_confidence'] as num?)?.toDouble(),
      confidenceTier: json['confidence_tier'] as String?,
      layerHeight: (json['layer_height'] as num?)?.toDouble(),
      layerHeightMin: (json['layer_height_min'] as num?)?.toDouble(),
      layerHeightMax: (json['layer_height_max'] as num?)?.toDouble(),
      infillDensity: (json['infill_density'] as num?)?.toInt(),
      printSpeed: (json['print_speed'] as num?)?.toInt(),
      wallCount: (json['wall_count'] as num?)?.toInt(),
      coolingFan: (json['cooling_fan'] as num?)?.toInt(),
      supportDensity: (json['support_density'] as num?)?.toInt(),
      costScore: (json['cost_score'] as num?)?.toInt(),
      qualityScore: (json['quality_score'] as num?)?.toInt(),
      speedScore: (json['speed_score'] as num?)?.toInt(),
      needsClarification: (json['needs_clarification'] as bool?) ?? false,
      clarificationQuestion: json['clarification_question'] as String?,
      clarificationField: json['clarification_field'] as String?,
      alternative: alt,
      orientationRx: (json['orientation_rx'] as num?)?.toDouble(),
      orientationRy: (json['orientation_ry'] as num?)?.toDouble(),
      orientationRz: (json['orientation_rz'] as num?)?.toDouble(),
      overhangReductionPct: (json['overhang_reduction_pct'] as num?)?.toDouble(),
      orientationPrintHeightMm: (json['orientation_print_height_mm'] as num?)?.toDouble(),
      userRating: json['user_rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
