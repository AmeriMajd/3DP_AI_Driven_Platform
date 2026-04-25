import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/stl_repository_impl.dart';
import '../../domain/stl_repository.dart';
import '../../domain/upload_state.dart';
import '../../domain/orientation_result.dart';
import '../viewmodels/upload_viewmodel.dart';

final stlRepositoryProvider = Provider<StlRepository>((ref) {
  return StlRepositoryImpl();
});

final uploadViewModelProvider =
    StateNotifierProvider<UploadViewModel, UploadState>((ref) {
  return UploadViewModel(ref.read(stlRepositoryProvider));
});

/// FutureProvider.family — charge les orientations pour un fileId donné.
///
/// Cache automatique Riverpod — un seul appel réseau par fileId.
/// Retourne [] si le fichier n'est pas encore 'ready'.
final orientationsProvider =
    FutureProvider.family<List<OrientationResult>, String>(
  (ref, fileId) async {
    final repo = ref.read(stlRepositoryProvider);
    final uploadState = ref.watch(uploadViewModelProvider);
    final file = uploadState.files
        .cast<dynamic>()
        .firstWhere((f) => f.id == fileId, orElse: () => null);

    if (file == null || file.status != 'ready') {
      return [];
    }

    return repo.getOrientations(id: fileId);
  },
);
