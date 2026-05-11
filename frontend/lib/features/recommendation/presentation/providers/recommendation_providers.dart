import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/recommendation_repository_impl.dart';
import '../../domain/estimate_payload.dart';
import '../../domain/recommendation_repository.dart';
import '../../domain/recommendation_state.dart';
import '../viewmodels/recommendation_viewmodel.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => RecommendationRepositoryImpl(),
);

final recommendationViewModelProvider =
    StateNotifierProvider<RecommendationViewModel, RecommendationState>(
  (ref) => RecommendationViewModel(
    ref.read(recommendationRepositoryProvider),
  ),
);

final estimateProvider =
    FutureProvider.family<EstimatePayload, String>(
  (ref, recommendationId) =>
      ref.read(recommendationRepositoryProvider).fetchEstimate(recommendationId),
);
