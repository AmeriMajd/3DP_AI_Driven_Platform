import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/printer_repository_impl.dart';
import '../domain/printer.dart';
import '../domain/printer_filter.dart';
import '../domain/printer_repository.dart';
import '../domain/printer_status.dart';
import '../../../shared/services/storage_service.dart';

final printerRepositoryProvider = Provider<PrinterRepository>((ref) {
  return PrinterRepositoryImpl();
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final role = await StorageService.getUserRole();
  return role?.toLowerCase() == 'admin';
});

final printersListProvider =
    FutureProvider.family<List<Printer>, PrinterFilter>((ref, filter) async {
      final repo = ref.read(printerRepositoryProvider);
      return repo.listPrinters(
        technology: filter.technology,
        status: filter.status,
      );
    });

final printerDetailProvider = FutureProvider.family<Printer, String>((
  ref,
  id,
) async {
  final repo = ref.read(printerRepositoryProvider);
  return repo.getPrinter(id: id);
});

// Polling removed — WS `printer.status` events invalidate this provider via
// PrinterDetailScreen's `ref.listen(wsTopicEventsProvider(printer:{id}))`.
final printerStatusProvider = FutureProvider.family<PrinterStatus, String>((
  ref,
  id,
) async {
  final repo = ref.read(printerRepositoryProvider);
  return repo.getPrinterStatus(id: id);
});
