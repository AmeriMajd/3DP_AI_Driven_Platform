import 'dart:typed_data';

import 'estimate_payload.dart';
import 'recommend_request.dart';
import 'recommendation_result.dart';

abstract class RecommendationRepository {
  Future<RecommendationResult> createRecommendation(RecommendRequest request);
  Future<RecommendationResult> rateRecommendation(String id, int rating);
  Future<RecommendationResult> updateParameters(String id, Map<String, dynamic> params);
  Future<List<RecommendationResult>> getHistory();

  Future<Uint8List> exportProfile(String id, String slicer);

  /// POST /estimate — compute & persist cost/time for a recommendation.
  Future<EstimatePayload> fetchEstimate(String recommendationId);
}
