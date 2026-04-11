import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/orientation_result.dart';
import '../providers/upload_provider.dart';

/// FutureProvider.family — charge les orientations pour un fileId donné.
///
/// Avantages par rapport à un champ dans UploadState :
/// - Cache automatique Riverpod — un seul appel réseau par fileId
/// - Loading / error / data gérés nativement avec AsyncValue
/// - Invalidation explicite via ref.invalidate(orientationsProvider(fileId))
///   — utile après une suppression ou si on veut forcer un refresh
/// - Aucune logique de cache manuelle dans UploadState
///
/// Usage dans un widget :
///   final orientationsAsync = ref.watch(orientationsProvider(fileId));
///   orientationsAsync.when(
///     data: (orientations) => ...,
///     loading: () => CircularProgressIndicator(),
///     error: (e, _) => Text('Error: $e'),
///   );
final orientationsProvider = FutureProvider.family<List<OrientationResult>, String>(
  (ref, fileId) async {
    final repo = ref.read(stlRepositoryProvider);

    // On attend que le fichier soit 'ready' avant de faire l'appel.
    // Si le fichier n'est pas encore ready, on retourne une liste vide
    // — le widget affichera le spinner "computing orientations".
    final uploadState = ref.watch(uploadProvider);
    final file = uploadState.files
        .cast<dynamic>()
        .firstWhere((f) => f.id == fileId, orElse: () => null);

    if (file == null || file.status != 'ready') {
      return [];
    }

    return repo.getOrientations(id: fileId);
  },
);