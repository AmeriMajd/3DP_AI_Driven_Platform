import 'package:dio/dio.dart';

import '../../../shared/services/dio_client.dart';
import '../domain/printer.dart';
import '../domain/printer_repository.dart';
import '../domain/printer_status.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final Dio _dio = DioClient.instance;

  @override
  Future<List<Printer>> listPrinters({
    PrinterTechnology? technology,
    PrinterStatusValue? status,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (technology != null) {
        query['technology'] = technology.apiValue;
      }
      if (status != null) {
        query['status'] = status.apiValue;
      }

      final response = await _dio.get(
        '/printers',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = response.data as List<dynamic>;
      return data
          .map((item) => Printer.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Printer> getPrinter({required String id}) async {
    try {
      final response = await _dio.get('/printers/$id');
      return Printer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Printer> createPrinter(PrinterCreate payload) async {
    try {
      final response = await _dio.post('/printers', data: payload.toJson());
      return Printer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<Printer> updatePrinter({
    required String id,
    required PrinterUpdate payload,
  }) async {
    try {
      final response = await _dio.put('/printers/$id', data: payload.toJson());
      return Printer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<void> deletePrinter({required String id}) async {
    try {
      await _dio.delete('/printers/$id');
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<PrinterStatus> getPrinterStatus({required String id}) async {
    try {
      final response = await _dio.get('/printers/$id/status');
      return PrinterStatus.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  @override
  Future<PrinterTestResult> testPrinter({required String id}) async {
    try {
      final response = await _dio.post('/printers/$id/test');
      return PrinterTestResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

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
          case 401:
            return 'Not authenticated';
          case 403:
            return 'Admin access required';
          case 404:
            return 'Printer not found';
          case 422:
            return 'Malformed request — please try again';
          case 500:
            return 'Server error — please try again later';
          default:
            return 'An unexpected error occurred';
        }
    }
  }
}
