import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recommendation_result.dart';
import 'recommendation_providers.dart';

/// Active technology filter — null means "All".
final historyTechnologyFilterProvider = StateProvider<String?>((ref) => null);

/// Active material filter — null means "All".
final historyMaterialFilterProvider = StateProvider<String?>((ref) => null);

/// Fetches the current user's recommendation history, re-running automatically
/// whenever either filter changes.
final recommendationHistoryProvider =
    FutureProvider<List<RecommendationResult>>((ref) {
  final technology = ref.watch(historyTechnologyFilterProvider);
  final material = ref.watch(historyMaterialFilterProvider);
  return ref.watch(recommendationRepositoryProvider).getHistory(
        technology: technology,
        material: material,
      );
});
