class AlternativeRecommendation {
  final String technology;
  final String material;
  final double? layerHeight;
  final int? infillDensity;
  final int? printSpeed;
  final int? wallCount;
  final int? coolingFan;
  final int? supportDensity;
  final double confidence;
  final int costScore;
  final int qualityScore;
  final int speedScore;

  const AlternativeRecommendation({
    required this.technology,
    required this.material,
    this.layerHeight,
    this.infillDensity,
    this.printSpeed,
    this.wallCount,
    this.coolingFan,
    this.supportDensity,
    required this.confidence,
    required this.costScore,
    required this.qualityScore,
    required this.speedScore,
  });

  factory AlternativeRecommendation.fromJson(Map<String, dynamic> json) {
    return AlternativeRecommendation(
      technology: json['technology'] as String,
      material: json['material'] as String,
      layerHeight: (json['layer_height'] as num?)?.toDouble(),
      infillDensity: (json['infill_density'] as num?)?.toInt(),
      printSpeed: (json['print_speed'] as num?)?.toInt(),
      wallCount: (json['wall_count'] as num?)?.toInt(),
      coolingFan: (json['cooling_fan'] as num?)?.toInt(),
      supportDensity: (json['support_density'] as num?)?.toInt(),
      confidence: (json['confidence'] as num).toDouble(),
      costScore: (json['cost_score'] as num).toInt(),
      qualityScore: (json['quality_score'] as num).toInt(),
      speedScore: (json['speed_score'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'technology': technology,
        'material': material,
        'layer_height': layerHeight,
        'infill_density': infillDensity,
        'print_speed': printSpeed,
        'wall_count': wallCount,
        'cooling_fan': coolingFan,
        'support_density': supportDensity,
        'confidence': confidence,
        'cost_score': costScore,
        'quality_score': qualityScore,
        'speed_score': speedScore,
      };
}
