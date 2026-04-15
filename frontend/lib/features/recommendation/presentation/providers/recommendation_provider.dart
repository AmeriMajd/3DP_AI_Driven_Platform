import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recommendation_repository.dart';
import '../../data/recommendation_repository_impl.dart';
import '../../domain/recommend_request.dart';
import '../../domain/recommendation_result.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepositoryImpl(),
);

// ── State ─────────────────────────────────────────────────────────────────────

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
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class RecommendationNotifier extends StateNotifier<RecommendationState> {
  final RecommendationRepository _repo;

  RecommendationNotifier(this._repo) : super(const RecommendationState());

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

  void reset() {
    state = const RecommendationState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final recommendationProvider =
    StateNotifierProvider<RecommendationNotifier, RecommendationState>(
  (ref) => RecommendationNotifier(
    ref.read(recommendationRepositoryProvider),
  ),
);
