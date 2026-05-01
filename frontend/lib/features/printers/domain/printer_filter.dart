import 'package:freezed_annotation/freezed_annotation.dart';

import 'printer.dart';

part 'printer_filter.freezed.dart';

@freezed
class PrinterFilter with _$PrinterFilter {
  const factory PrinterFilter({
    PrinterTechnology? technology,
    PrinterStatusValue? status,
  }) = _PrinterFilter;
}
