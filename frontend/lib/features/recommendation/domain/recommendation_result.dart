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
  final String priorityFace;

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
    required this.priorityFace,
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
    this.userRating,
    required this.createdAt,
  });

  RecommendationResult copyWith({int? userRating}) {
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
      priorityFace: priorityFace,
      technology: technology,
      material: material,
      technologyConfidence: technologyConfidence,
      materialConfidence: materialConfidence,
      confidenceTier: confidenceTier,
      layerHeight: layerHeight,
      layerHeightMin: layerHeightMin,
      layerHeightMax: layerHeightMax,
      infillDensity: infillDensity,
      printSpeed: printSpeed,
      wallCount: wallCount,
      coolingFan: coolingFan,
      supportDensity: supportDensity,
      costScore: costScore,
      qualityScore: qualityScore,
      speedScore: speedScore,
      needsClarification: needsClarification,
      clarificationQuestion: clarificationQuestion,
      clarificationField: clarificationField,
      alternative: alternative,
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
      priorityFace: json['priority_face'] as String,
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
      userRating: json['user_rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
