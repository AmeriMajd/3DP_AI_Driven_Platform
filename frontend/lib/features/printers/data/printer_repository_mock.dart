import 'dart:async';

import '../domain/printer.dart';
import '../domain/printer_repository.dart';
import '../domain/printer_status.dart';

class MockPrinterRepository implements PrinterRepository {
  final List<Printer> _printers = [
    Printer(
      id: 'mock-001',
      name: 'Prusa MK4 #1',
      model: 'MK4',
      technology: PrinterTechnology.fdm,
      buildVolumeX: 250,
      buildVolumeY: 210,
      buildVolumeZ: 220,
      connectorType: PrinterConnectorType.mock,
      status: PrinterStatusValue.idle,
      materialsSupported: const ['PLA', 'PETG', 'ABS'],
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 3)),
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    Printer(
      id: 'mock-002',
      name: 'Bambu X1C #1',
      model: 'X1C',
      technology: PrinterTechnology.fdm,
      buildVolumeX: 256,
      buildVolumeY: 256,
      buildVolumeZ: 256,
      connectorType: PrinterConnectorType.mock,
      status: PrinterStatusValue.printing,
      materialsSupported: const ['PLA', 'PETG', 'TPU'],
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Printer(
      id: 'mock-003',
      name: 'Formlabs Form 3',
      model: 'Form 3',
      technology: PrinterTechnology.sla,
      buildVolumeX: 145,
      buildVolumeY: 145,
      buildVolumeZ: 185,
      connectorType: PrinterConnectorType.mock,
      status: PrinterStatusValue.idle,
      materialsSupported: const ['Standard Resin', 'Tough'],
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 12)),
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  @override
  Future<List<Printer>> listPrinters({
    PrinterTechnology? technology,
    PrinterStatusValue? status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    Iterable<Printer> items = _printers;
    if (technology != null) {
      items = items.where((p) => p.technology == technology);
    }
    if (status != null) {
      items = items.where((p) => p.status == status);
    }
    return items.toList();
  }

  @override
  Future<Printer> getPrinter({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final printer = _printers.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Printer not found'),
    );
    return printer;
  }

  @override
  Future<Printer> createPrinter(PrinterCreate payload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final printer = Printer(
      id: 'mock-${now.millisecondsSinceEpoch}',
      name: payload.name,
      model: payload.model,
      technology: payload.technology,
      buildVolumeX: payload.buildVolumeX,
      buildVolumeY: payload.buildVolumeY,
      buildVolumeZ: payload.buildVolumeZ,
      connectorType: payload.connectorType,
      status: payload.status,
      materialsSupported: payload.materialsSupported,
      lastSeenAt: null,
      createdAt: now,
    );
    _printers.insert(0, printer);
    return printer;
  }

  @override
  Future<Printer> updatePrinter({
    required String id,
    required PrinterUpdate payload,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _printers.indexWhere((p) => p.id == id);
    if (index == -1) {
      throw Exception('Printer not found');
    }

    final current = _printers[index];
    final updated = current.copyWith(
      name: payload.name ?? current.name,
      model: payload.model ?? current.model,
      technology: payload.technology ?? current.technology,
      buildVolumeX: payload.buildVolumeX ?? current.buildVolumeX,
      buildVolumeY: payload.buildVolumeY ?? current.buildVolumeY,
      buildVolumeZ: payload.buildVolumeZ ?? current.buildVolumeZ,
      connectorType: payload.connectorType ?? current.connectorType,
      status: payload.status ?? current.status,
      materialsSupported:
          payload.materialsSupported ?? current.materialsSupported,
    );

    _printers[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePrinter({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _printers.removeWhere((p) => p.id == id);
  }

  @override
  Future<PrinterStatus> getPrinterStatus({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final printer = await getPrinter(id: id);
    final isPrinting = printer.status == PrinterStatusValue.printing;

    return PrinterStatus(
      printerId: printer.id,
      status: printer.status,
      currentJobId: isPrinting ? 'job-${printer.id}' : null,
      progressPct: isPrinting ? 42.0 : null,
      temperatureNozzle: isPrinting ? 210.0 : null,
      temperatureBed: isPrinting ? 60.0 : null,
      lastSeenAt: DateTime.now(),
    );
  }

  @override
  Future<PrinterTestResult> testPrinter({required String id}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    await getPrinter(id: id);
    return PrinterTestResult(printerId: id, ok: true, message: 'Mock OK');
  }
}
