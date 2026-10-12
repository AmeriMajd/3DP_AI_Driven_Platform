import 'printer.dart';

enum PrinterStateStatus { initial, loading, success, error }

class PrinterState {
  final PrinterStateStatus status;
  final List<Printer> printers;
  final Printer? selectedPrinter;
  final String? errorMessage;

  const PrinterState({
    this.status = PrinterStateStatus.initial,
    this.printers = const [],
    this.selectedPrinter,
    this.errorMessage,
  });

  PrinterState copyWith({
    PrinterStateStatus? status,
    List<Printer>? printers,
    Printer? selectedPrinter,
    String? errorMessage,
    bool clearSelectedPrinter = false,
    bool clearError = false,
  }) {
    return PrinterState(
      status: status ?? this.status,
      printers: printers ?? this.printers,
      selectedPrinter: clearSelectedPrinter ? null : (selectedPrinter ?? this.selectedPrinter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
