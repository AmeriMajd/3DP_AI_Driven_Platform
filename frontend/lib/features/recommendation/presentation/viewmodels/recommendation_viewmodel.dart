import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recommendation_repository.dart';
import '../../domain/recommendation_state.dart';
import '../../domain/recommend_request.dart';

class RecommendationViewModel extends StateNotifier<RecommendationState> {
  final RecommendationRepository _repo;

  RecommendationViewModel(this._repo) : super(const RecommendationState());

  Future<void> submit(RecommendRequest request) async {
    state = state.copyWith(
      status: RecommendationStatus.loading,
      clearError: true,
    );
    try {
      final result = await _repo.createRecommendation(request);
      state = state.copyWith(
        status: RecommendationStatus.success,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        status: RecommendationStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> rate(String id, int rating) async {
    try {
      final updated = await _repo.rateRecommendation(id, rating);
      state = state.copyWith(result: updated);
    } catch (_) {
      // Rating failure is non-critical — swallow silently
    }
  }

  Future<void> updateParameters(String id, Map<String, dynamic> params) async {
    final updated = await _repo.updateParameters(id, params);
    state = state.copyWith(result: updated);
  }

  void reset() {
    state = const RecommendationState();
  }
}
