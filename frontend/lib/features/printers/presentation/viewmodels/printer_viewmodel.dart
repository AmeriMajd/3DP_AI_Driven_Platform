import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/printer.dart';
import '../../domain/printer_repository.dart';
import '../../domain/printer_state.dart';

class PrinterViewModel extends StateNotifier<PrinterState> {
  final PrinterRepository _repo;

  PrinterViewModel(this._repo) : super(const PrinterState());

  Future<void> loadPrinters({
    PrinterTechnology? technology,
    PrinterStatusValue? status,
  }) async {
    state = state.copyWith(status: PrinterStateStatus.loading, clearError: true);
    try {
      final printers = await _repo.listPrinters(
        technology: technology,
        status: status,
      );
      state = state.copyWith(
        status: PrinterStateStatus.success,
        printers: printers,
      );
    } catch (e) {
      state = state.copyWith(
        status: PrinterStateStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadPrinter(String id) async {
    state = state.copyWith(status: PrinterStateStatus.loading, clearError: true);
    try {
      final printer = await _repo.getPrinter(id: id);
      state = state.copyWith(
        status: PrinterStateStatus.success,
        selectedPrinter: printer,
      );
    } catch (e) {
      state = state.copyWith(
        status: PrinterStateStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> createPrinter(PrinterCreate payload) async {
    state = state.copyWith(status: PrinterStateStatus.loading, clearError: true);
    try {
      final printer = await _repo.createPrinter(payload);
      state = state.copyWith(
        status: PrinterStateStatus.success,
        printers: [printer, ...state.printers],
      );
    } catch (e) {
      state = state.copyWith(
        status: PrinterStateStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updatePrinter({
    required String id,
    required PrinterUpdate payload,
  }) async {
    state = state.copyWith(status: PrinterStateStatus.loading, clearError: true);
    try {
      final updated = await _repo.updatePrinter(id: id, payload: payload);
      final updatedList = state.printers.map((p) => p.id == id ? updated : p).toList();
      state = state.copyWith(
        status: PrinterStateStatus.success,
        printers: updatedList,
        selectedPrinter: updated,
      );
    } catch (e) {
      state = state.copyWith(
        status: PrinterStateStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> deletePrinter(String id) async {
    state = state.copyWith(status: PrinterStateStatus.loading, clearError: true);
    try {
      await _repo.deletePrinter(id: id);
      state = state.copyWith(
        status: PrinterStateStatus.success,
        printers: state.printers.where((p) => p.id != id).toList(),
        clearSelectedPrinter: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: PrinterStateStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void reset() {
    state = const PrinterState();
  }
}
