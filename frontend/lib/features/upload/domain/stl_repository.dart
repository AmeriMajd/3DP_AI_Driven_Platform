import 'dart:typed_data';

import 'stl_file.dart';
import 'orientation_result.dart';

abstract class StlRepository {
  /// POST /stl/upload — upload un fichier STL ou 3MF
  Future<STLFile> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
    Uint8List? fileBytes,
  });

  /// GET /stl/ — liste tous les fichiers de l'utilisateur
  Future<List<STLFile>> getFiles();

  /// GET /stl/{id} — récupère les métadonnées d'un fichier
  Future<STLFile> getFile({required String id});

  /// GET /stl/{id}/orientations — récupère les orientations calculées pour un fichier
  Future<List<OrientationResult>> getOrientations({required String id});

  /// DELETE /stl/{id} — supprime un fichier
  Future<void> deleteFile({required String id});

  /// POST /stl/{id}/reprocess — relance l'analyse geometry + preview
  Future<STLFile> reprocessFile({required String id});
}
