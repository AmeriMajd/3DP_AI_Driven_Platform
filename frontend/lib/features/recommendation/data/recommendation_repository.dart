import '../domain/recommend_request.dart';
import '../domain/recommendation_result.dart';

abstract class RecommendationRepository {
  Future<RecommendationResult> createRecommendation(RecommendRequest request);
  Future<RecommendationResult> rateRecommendation(String id, int rating);
  Future<List<RecommendationResult>> getHistory();
}
