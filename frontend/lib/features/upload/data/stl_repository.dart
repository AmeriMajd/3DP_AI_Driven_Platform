import '../domain/stl_file.dart';

abstract class StlRepository {
  /// POST /stl/upload — upload un fichier STL ou 3MF
  Future<STLFile> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
  });

  /// GET /stl/ — liste tous les fichiers de l'utilisateur
  Future<List<STLFile>> getFiles();

  /// GET /stl/{id} — récupère les métadonnées d'un fichier
Future<STLFile> getFile({required String id});

  /// DELETE /stl/{id} — supprime un fichier
  Future<void> deleteFile({required String id});
}