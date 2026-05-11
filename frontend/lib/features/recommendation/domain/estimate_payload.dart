/// Response shape for POST /estimate.
class EstimateValues {
  final double? estimatedCost;
  final int? estimatedTimeMinutes;
  final String? currency;
  final String? pricingVersion;
  final String? estimationConfidence;

  const EstimateValues({
    this.estimatedCost,
    this.estimatedTimeMinutes,
    this.currency,
    this.pricingVersion,
    this.estimationConfidence,
  });

  factory EstimateValues.fromJson(Map<String, dynamic> json) {
    return EstimateValues(
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      estimatedTimeMinutes: (json['estimated_time_minutes'] as num?)?.toInt(),
      currency: json['currency'] as String?,
      pricingVersion: json['pricing_version'] as String?,
      estimationConfidence: json['estimation_confidence'] as String?,
    );
  }
}

class EstimatePayload {
  final String recommendationId;
  final EstimateValues primary;
  final EstimateValues? alternative;

  const EstimatePayload({
    required this.recommendationId,
    required this.primary,
    this.alternative,
  });

  factory EstimatePayload.fromJson(Map<String, dynamic> json) {
    final altRaw = json['alternative'];
    return EstimatePayload(
      recommendationId: json['recommendation_id'].toString(),
      primary: EstimateValues.fromJson(
          json['primary'] as Map<String, dynamic>),
      alternative: altRaw is Map<String, dynamic>
          ? EstimateValues.fromJson(altRaw)
          : null,
    );
  }
}
