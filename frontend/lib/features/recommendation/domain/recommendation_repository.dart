import 'dart:typed_data';

import 'recommend_request.dart';
import 'recommendation_result.dart';

abstract class RecommendationRepository {
  Future<RecommendationResult> createRecommendation(RecommendRequest request);
  Future<RecommendationResult> rateRecommendation(String id, int rating);
  Future<RecommendationResult> updateParameters(String id, Map<String, dynamic> params);
  Future<List<RecommendationResult>> getHistory();

  Future<Uint8List> exportProfile(String id, String slicer);
}
