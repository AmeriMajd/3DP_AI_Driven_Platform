import 'dart:typed_data';

import 'recommend_request.dart';
import 'recommendation_result.dart';

abstract class RecommendationRepository {
  Future<RecommendationResult> createRecommendation(RecommendRequest request);
  Future<RecommendationResult> rateRecommendation(String id, int rating);
  Future<RecommendationResult> updateParameters(String id, Map<String, dynamic> params);
  Future<List<RecommendationResult>> getHistory();

  /// Download print parameters as a slicer config file.
  /// [slicer] must be `"cura"` or `"prusaslicer"`.
  /// Returns the raw bytes of the config file.
  Future<Uint8List> exportProfile(String id, String slicer);
}
