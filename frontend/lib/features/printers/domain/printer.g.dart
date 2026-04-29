// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PrinterImpl _$$PrinterImplFromJson(Map<String, dynamic> json) =>
    _$PrinterImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String?,
      technology: $enumDecode(_$PrinterTechnologyEnumMap, json['technology']),
      buildVolumeX: (json['build_volume_x'] as num?)?.toDouble(),
      buildVolumeY: (json['build_volume_y'] as num?)?.toDouble(),
      buildVolumeZ: (json['build_volume_z'] as num?)?.toDouble(),
      connectorType: $enumDecode(
        _$PrinterConnectorTypeEnumMap,
        json['connector_type'],
      ),
      status: $enumDecode(_$PrinterStatusValueEnumMap, json['status']),
      materialsSupported: (json['materials_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$PrinterImplToJson(_$PrinterImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'model': instance.model,
      'technology': _$PrinterTechnologyEnumMap[instance.technology]!,
      'build_volume_x': instance.buildVolumeX,
      'build_volume_y': instance.buildVolumeY,
      'build_volume_z': instance.buildVolumeZ,
      'connector_type': _$PrinterConnectorTypeEnumMap[instance.connectorType]!,
      'status': _$PrinterStatusValueEnumMap[instance.status]!,
      'materials_supported': instance.materialsSupported,
      'last_seen_at': instance.lastSeenAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$PrinterTechnologyEnumMap = {
  PrinterTechnology.fdm: 'FDM',
  PrinterTechnology.sla: 'SLA',
};

const _$PrinterConnectorTypeEnumMap = {
  PrinterConnectorType.octoprint: 'octoprint',
  PrinterConnectorType.prusalink: 'prusalink',
  PrinterConnectorType.mock: 'mock',
  PrinterConnectorType.manual: 'manual',
};

const _$PrinterStatusValueEnumMap = {
  PrinterStatusValue.idle: 'idle',
  PrinterStatusValue.printing: 'printing',
  PrinterStatusValue.error: 'error',
  PrinterStatusValue.offline: 'offline',
  PrinterStatusValue.maintenance: 'maintenance',
};

_$PrinterCreateImpl _$$PrinterCreateImplFromJson(Map<String, dynamic> json) =>
    _$PrinterCreateImpl(
      name: json['name'] as String,
      model: json['model'] as String?,
      technology: $enumDecode(_$PrinterTechnologyEnumMap, json['technology']),
      buildVolumeX: (json['build_volume_x'] as num?)?.toDouble(),
      buildVolumeY: (json['build_volume_y'] as num?)?.toDouble(),
      buildVolumeZ: (json['build_volume_z'] as num?)?.toDouble(),
      connectorType:
          $enumDecodeNullable(
            _$PrinterConnectorTypeEnumMap,
            json['connector_type'],
          ) ??
          PrinterConnectorType.mock,
      connectionUrl: json['connection_url'] as String?,
      status:
          $enumDecodeNullable(_$PrinterStatusValueEnumMap, json['status']) ??
          PrinterStatusValue.offline,
      materialsSupported: (json['materials_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      apiKey: json['api_key'] as String?,
    );

Map<String, dynamic> _$$PrinterCreateImplToJson(_$PrinterCreateImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'model': instance.model,
      'technology': _$PrinterTechnologyEnumMap[instance.technology]!,
      'build_volume_x': instance.buildVolumeX,
      'build_volume_y': instance.buildVolumeY,
      'build_volume_z': instance.buildVolumeZ,
      'connector_type': _$PrinterConnectorTypeEnumMap[instance.connectorType]!,
      'connection_url': instance.connectionUrl,
      'status': _$PrinterStatusValueEnumMap[instance.status]!,
      'materials_supported': instance.materialsSupported,
      'api_key': instance.apiKey,
    };

_$PrinterUpdateImpl _$$PrinterUpdateImplFromJson(Map<String, dynamic> json) =>
    _$PrinterUpdateImpl(
      name: json['name'] as String?,
      model: json['model'] as String?,
      technology: $enumDecodeNullable(
        _$PrinterTechnologyEnumMap,
        json['technology'],
      ),
      buildVolumeX: (json['build_volume_x'] as num?)?.toDouble(),
      buildVolumeY: (json['build_volume_y'] as num?)?.toDouble(),
      buildVolumeZ: (json['build_volume_z'] as num?)?.toDouble(),
      connectorType: $enumDecodeNullable(
        _$PrinterConnectorTypeEnumMap,
        json['connector_type'],
      ),
      connectionUrl: json['connection_url'] as String?,
      status: $enumDecodeNullable(_$PrinterStatusValueEnumMap, json['status']),
      materialsSupported: (json['materials_supported'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      apiKey: json['api_key'] as String?,
    );

Map<String, dynamic> _$$PrinterUpdateImplToJson(
  _$PrinterUpdateImpl instance,
) => <String, dynamic>{
  if (instance.name case final value?) 'name': value,
  if (instance.model case final value?) 'model': value,
  if (_$PrinterTechnologyEnumMap[instance.technology] case final value?)
    'technology': value,
  if (instance.buildVolumeX case final value?) 'build_volume_x': value,
  if (instance.buildVolumeY case final value?) 'build_volume_y': value,
  if (instance.buildVolumeZ case final value?) 'build_volume_z': value,
  if (_$PrinterConnectorTypeEnumMap[instance.connectorType] case final value?)
    'connector_type': value,
  if (instance.connectionUrl case final value?) 'connection_url': value,
  if (_$PrinterStatusValueEnumMap[instance.status] case final value?)
    'status': value,
  if (instance.materialsSupported case final value?)
    'materials_supported': value,
  if (instance.apiKey case final value?) 'api_key': value,
};
