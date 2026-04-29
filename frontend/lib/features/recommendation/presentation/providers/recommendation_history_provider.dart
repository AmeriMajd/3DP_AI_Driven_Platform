import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/recommendation_result.dart';
import 'recommendation_providers.dart';

/// Active technology filter — null means "All".
final historyTechnologyFilterProvider = StateProvider<String?>((ref) => null);

/// Active material filter — null means "All".
final historyMaterialFilterProvider = StateProvider<String?>((ref) => null);

/// Fetches all history once, then filters client-side when filter chips change.
final recommendationHistoryProvider =
    FutureProvider<List<RecommendationResult>>((ref) async {
  final technology = ref.watch(historyTechnologyFilterProvider);
  final material = ref.watch(historyMaterialFilterProvider);
  final all = await ref.watch(recommendationRepositoryProvider).getHistory();
  return all.where((r) {
    if (technology != null && r.technology != technology) return false;
    if (material != null && r.material != material) return false;
    return true;
  }).toList();
});
