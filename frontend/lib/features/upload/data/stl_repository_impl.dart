import 'package:dio/dio.dart';
import '../../../shared/services/dio_client.dart';
import '../domain/stl_file.dart';
import 'stl_repository.dart';

class StlRepositoryImpl implements StlRepository {
  final Dio _dio = DioClient.instance;

  /// POST /stl/upload
  @override
  Future<STLFile> uploadFile({
    required String filePath,
    required String filename,
    required int fileSize,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: filename,
        ),
      });

      final response = await _dio.post(
        '/stl/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return STLFile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// GET /stl/
  @override
  Future<List<STLFile>> getFiles() async {
    try {
      final response = await _dio.get('/stl/');
      final data = response.data as Map<String, dynamic>;
      final files = data['files'] as List<dynamic>;
      return files
          .map((f) => STLFile.fromJson(f as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// GET /stl/{id}
  @override
  Future<STLFile> getFile({required String id}) async {
    try {
      final response = await _dio.get('/stl/$id');
      return STLFile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// DELETE /stl/{id}
  @override
  Future<void> deleteFile({required String id}) async {
    try {
      await _dio.delete('/stl/$id');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Extrait le message d'erreur lisible depuis la réponse Dio
  String _handleError(DioException e) {
    if (e.response?.data != null) {
      final detail = e.response?.data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg'] ?? 'Validation error';
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout — check your network';
      case DioExceptionType.connectionError:
        return 'Cannot reach server — is the backend running?';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond';
      default:
        switch (e.response?.statusCode) {
        case 400: return 'Invalid file — check extension and size';
        case 401: return 'Not authenticated';
        case 404: return 'File not found';
        case 413: return 'File exceeds 50 MB limit';
        case 422: return 'Malformed request — please try again';
        case 500: return 'Server error — please try again later';
        default:  return 'An unexpected error occurred';
      }
    }
  }
}