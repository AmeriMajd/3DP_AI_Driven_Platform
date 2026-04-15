class AlternativeRecommendation {
  final String technology;
  final String material;
  final double confidence;
  final int costScore;
  final int qualityScore;
  final int speedScore;

  const AlternativeRecommendation({
    required this.technology,
    required this.material,
    required this.confidence,
    required this.costScore,
    required this.qualityScore,
    required this.speedScore,
  });

  factory AlternativeRecommendation.fromJson(Map<String, dynamic> json) {
    return AlternativeRecommendation(
      technology: json['technology'] as String,
      material: json['material'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      costScore: (json['cost_score'] as num).toInt(),
      qualityScore: (json['quality_score'] as num).toInt(),
      speedScore: (json['speed_score'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'technology': technology,
        'material': material,
        'confidence': confidence,
        'cost_score': costScore,
        'quality_score': qualityScore,
        'speed_score': speedScore,
      };
}
