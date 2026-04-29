// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'printer.freezed.dart';
part 'printer.g.dart';

@JsonEnum(alwaysCreate: true)
enum PrinterTechnology {
  @JsonValue('FDM')
  fdm,
  @JsonValue('SLA')
  sla,
}

@JsonEnum(alwaysCreate: true)
enum PrinterConnectorType {
  @JsonValue('octoprint')
  octoprint,
  @JsonValue('prusalink')
  prusalink,
  @JsonValue('mock')
  mock,
  @JsonValue('manual')
  manual,
}

@JsonEnum(alwaysCreate: true)
enum PrinterStatusValue {
  @JsonValue('idle')
  idle,
  @JsonValue('printing')
  printing,
  @JsonValue('error')
  error,
  @JsonValue('offline')
  offline,
  @JsonValue('maintenance')
  maintenance,
}

extension PrinterTechnologyX on PrinterTechnology {
  String get apiValue {
    switch (this) {
      case PrinterTechnology.fdm:
        return 'FDM';
      case PrinterTechnology.sla:
        return 'SLA';
    }
  }
}

extension PrinterStatusValueX on PrinterStatusValue {
  String get apiValue {
    switch (this) {
      case PrinterStatusValue.idle:
        return 'idle';
      case PrinterStatusValue.printing:
        return 'printing';
      case PrinterStatusValue.error:
        return 'error';
      case PrinterStatusValue.offline:
        return 'offline';
      case PrinterStatusValue.maintenance:
        return 'maintenance';
    }
  }
}

@freezed
class Printer with _$Printer {
  const factory Printer({
    required String id,
    required String name,
    String? model,
    required PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type')
    required PrinterConnectorType connectorType,
    required PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Printer;

  factory Printer.fromJson(Map<String, dynamic> json) =>
      _$PrinterFromJson(json);
}

@freezed
class PrinterCreate with _$PrinterCreate {
  const factory PrinterCreate({
    required String name,
    String? model,
    required PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type')
    @Default(PrinterConnectorType.mock)
    PrinterConnectorType connectorType,
    @JsonKey(name: 'connection_url') String? connectionUrl,
    @Default(PrinterStatusValue.offline) PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'api_key') String? apiKey,
  }) = _PrinterCreate;

  factory PrinterCreate.fromJson(Map<String, dynamic> json) =>
      _$PrinterCreateFromJson(json);
}

@freezed
class PrinterUpdate with _$PrinterUpdate {
  @JsonSerializable(includeIfNull: false)
  const factory PrinterUpdate({
    String? name,
    String? model,
    PrinterTechnology? technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type') PrinterConnectorType? connectorType,
    @JsonKey(name: 'connection_url') String? connectionUrl,
    PrinterStatusValue? status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'api_key') String? apiKey,
  }) = _PrinterUpdate;

  factory PrinterUpdate.fromJson(Map<String, dynamic> json) =>
      _$PrinterUpdateFromJson(json);
}
