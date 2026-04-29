import 'package:freezed_annotation/freezed_annotation.dart';

import 'printer.dart';

part 'printer_status.freezed.dart';
part 'printer_status.g.dart';

@freezed
class PrinterStatus with _$PrinterStatus {
  const factory PrinterStatus({
    @JsonKey(name: 'printer_id') required String printerId,
    required PrinterStatusValue status,
    @JsonKey(name: 'current_job_id') String? currentJobId,
    @JsonKey(name: 'progress_pct') double? progressPct,
    @JsonKey(name: 'temperature_nozzle') double? temperatureNozzle,
    @JsonKey(name: 'temperature_bed') double? temperatureBed,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
  }) = _PrinterStatus;

  factory PrinterStatus.fromJson(Map<String, dynamic> json) =>
      _$PrinterStatusFromJson(json);
}

@freezed
class PrinterTestResult with _$PrinterTestResult {
  const factory PrinterTestResult({
    @JsonKey(name: 'printer_id') required String printerId,
    required bool ok,
    required String message,
  }) = _PrinterTestResult;

  factory PrinterTestResult.fromJson(Map<String, dynamic> json) =>
      _$PrinterTestResultFromJson(json);
}
