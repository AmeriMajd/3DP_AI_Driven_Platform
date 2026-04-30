// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PrinterStatusImpl _$$PrinterStatusImplFromJson(Map<String, dynamic> json) =>
    _$PrinterStatusImpl(
      printerId: json['printer_id'] as String,
      status: $enumDecode(_$PrinterStatusValueEnumMap, json['status']),
      currentJobId: json['current_job_id'] as String?,
      progressPct: (json['progress_pct'] as num?)?.toDouble(),
      temperatureNozzle: (json['temperature_nozzle'] as num?)?.toDouble(),
      temperatureBed: (json['temperature_bed'] as num?)?.toDouble(),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
    );

Map<String, dynamic> _$$PrinterStatusImplToJson(_$PrinterStatusImpl instance) =>
    <String, dynamic>{
      'printer_id': instance.printerId,
      'status': _$PrinterStatusValueEnumMap[instance.status]!,
      'current_job_id': instance.currentJobId,
      'progress_pct': instance.progressPct,
      'temperature_nozzle': instance.temperatureNozzle,
      'temperature_bed': instance.temperatureBed,
      'last_seen_at': instance.lastSeenAt?.toIso8601String(),
    };

const _$PrinterStatusValueEnumMap = {
  PrinterStatusValue.idle: 'idle',
  PrinterStatusValue.printing: 'printing',
  PrinterStatusValue.error: 'error',
  PrinterStatusValue.offline: 'offline',
  PrinterStatusValue.maintenance: 'maintenance',
};

_$PrinterTestResultImpl _$$PrinterTestResultImplFromJson(
  Map<String, dynamic> json,
) => _$PrinterTestResultImpl(
  printerId: json['printer_id'] as String,
  ok: json['ok'] as bool,
  message: json['message'] as String,
);

Map<String, dynamic> _$$PrinterTestResultImplToJson(
  _$PrinterTestResultImpl instance,
) => <String, dynamic>{
  'printer_id': instance.printerId,
  'ok': instance.ok,
  'message': instance.message,
};
