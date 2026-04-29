import 'printer.dart';
import 'printer_status.dart';

abstract class PrinterRepository {
  Future<List<Printer>> listPrinters({
    PrinterTechnology? technology,
    PrinterStatusValue? status,
  });

  Future<Printer> getPrinter({required String id});

  Future<Printer> createPrinter(PrinterCreate payload);

  Future<Printer> updatePrinter({
    required String id,
    required PrinterUpdate payload,
  });

  Future<void> deletePrinter({required String id});

  Future<PrinterStatus> getPrinterStatus({required String id});

  Future<PrinterTestResult> testPrinter({required String id});
}
