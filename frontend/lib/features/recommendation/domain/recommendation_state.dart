import 'recommendation_result.dart';

enum RecommendationStatus { initial, loading, success, error }

class RecommendationState {
  final RecommendationStatus status;
  final RecommendationResult? result;
  final String? errorMessage;

  const RecommendationState({
    this.status = RecommendationStatus.initial,
    this.result,
    this.errorMessage,
  });

  RecommendationState copyWith({
    RecommendationStatus? status,
    RecommendationResult? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return RecommendationState(
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
