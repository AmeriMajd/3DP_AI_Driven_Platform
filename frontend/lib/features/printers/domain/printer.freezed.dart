// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'printer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Printer _$PrinterFromJson(Map<String, dynamic> json) {
  return _Printer.fromJson(json);
}

/// @nodoc
mixin _$Printer {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  PrinterTechnology get technology => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ => throw _privateConstructorUsedError;
  @JsonKey(name: 'connector_type')
  PrinterConnectorType get connectorType => throw _privateConstructorUsedError;
  PrinterStatusValue get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_seen_at')
  DateTime? get lastSeenAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Printer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Printer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterCopyWith<Printer> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterCopyWith<$Res> {
  factory $PrinterCopyWith(Printer value, $Res Function(Printer) then) =
      _$PrinterCopyWithImpl<$Res, Printer>;
  @useResult
  $Res call({
    String id,
    String name,
    String? model,
    PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type') PrinterConnectorType connectorType,
    PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$PrinterCopyWithImpl<$Res, $Val extends Printer>
    implements $PrinterCopyWith<$Res> {
  _$PrinterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Printer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? model = freezed,
    Object? technology = null,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = null,
    Object? status = null,
    Object? materialsSupported = freezed,
    Object? lastSeenAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            technology: null == technology
                ? _value.technology
                : technology // ignore: cast_nullable_to_non_nullable
                      as PrinterTechnology,
            buildVolumeX: freezed == buildVolumeX
                ? _value.buildVolumeX
                : buildVolumeX // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeY: freezed == buildVolumeY
                ? _value.buildVolumeY
                : buildVolumeY // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeZ: freezed == buildVolumeZ
                ? _value.buildVolumeZ
                : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                      as double?,
            connectorType: null == connectorType
                ? _value.connectorType
                : connectorType // ignore: cast_nullable_to_non_nullable
                      as PrinterConnectorType,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PrinterStatusValue,
            materialsSupported: freezed == materialsSupported
                ? _value.materialsSupported
                : materialsSupported // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            lastSeenAt: freezed == lastSeenAt
                ? _value.lastSeenAt
                : lastSeenAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterImplCopyWith<$Res> implements $PrinterCopyWith<$Res> {
  factory _$$PrinterImplCopyWith(
    _$PrinterImpl value,
    $Res Function(_$PrinterImpl) then,
  ) = __$$PrinterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? model,
    PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type') PrinterConnectorType connectorType,
    PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$PrinterImplCopyWithImpl<$Res>
    extends _$PrinterCopyWithImpl<$Res, _$PrinterImpl>
    implements _$$PrinterImplCopyWith<$Res> {
  __$$PrinterImplCopyWithImpl(
    _$PrinterImpl _value,
    $Res Function(_$PrinterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Printer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? model = freezed,
    Object? technology = null,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = null,
    Object? status = null,
    Object? materialsSupported = freezed,
    Object? lastSeenAt = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$PrinterImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        technology: null == technology
            ? _value.technology
            : technology // ignore: cast_nullable_to_non_nullable
                  as PrinterTechnology,
        buildVolumeX: freezed == buildVolumeX
            ? _value.buildVolumeX
            : buildVolumeX // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeY: freezed == buildVolumeY
            ? _value.buildVolumeY
            : buildVolumeY // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeZ: freezed == buildVolumeZ
            ? _value.buildVolumeZ
            : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                  as double?,
        connectorType: null == connectorType
            ? _value.connectorType
            : connectorType // ignore: cast_nullable_to_non_nullable
                  as PrinterConnectorType,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PrinterStatusValue,
        materialsSupported: freezed == materialsSupported
            ? _value._materialsSupported
            : materialsSupported // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        lastSeenAt: freezed == lastSeenAt
            ? _value.lastSeenAt
            : lastSeenAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PrinterImpl implements _Printer {
  const _$PrinterImpl({
    required this.id,
    required this.name,
    this.model,
    required this.technology,
    @JsonKey(name: 'build_volume_x') this.buildVolumeX,
    @JsonKey(name: 'build_volume_y') this.buildVolumeY,
    @JsonKey(name: 'build_volume_z') this.buildVolumeZ,
    @JsonKey(name: 'connector_type') required this.connectorType,
    required this.status,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'last_seen_at') this.lastSeenAt,
    @JsonKey(name: 'created_at') required this.createdAt,
  }) : _materialsSupported = materialsSupported;

  factory _$PrinterImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? model;
  @override
  final PrinterTechnology technology;
  @override
  @JsonKey(name: 'build_volume_x')
  final double? buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  final double? buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  final double? buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  final PrinterConnectorType connectorType;
  @override
  final PrinterStatusValue status;
  final List<String>? _materialsSupported;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported {
    final value = _materialsSupported;
    if (value == null) return null;
    if (_materialsSupported is EqualUnmodifiableListView)
      return _materialsSupported;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'last_seen_at')
  final DateTime? lastSeenAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'Printer(id: $id, name: $name, model: $model, technology: $technology, buildVolumeX: $buildVolumeX, buildVolumeY: $buildVolumeY, buildVolumeZ: $buildVolumeZ, connectorType: $connectorType, status: $status, materialsSupported: $materialsSupported, lastSeenAt: $lastSeenAt, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.technology, technology) ||
                other.technology == technology) &&
            (identical(other.buildVolumeX, buildVolumeX) ||
                other.buildVolumeX == buildVolumeX) &&
            (identical(other.buildVolumeY, buildVolumeY) ||
                other.buildVolumeY == buildVolumeY) &&
            (identical(other.buildVolumeZ, buildVolumeZ) ||
                other.buildVolumeZ == buildVolumeZ) &&
            (identical(other.connectorType, connectorType) ||
                other.connectorType == connectorType) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._materialsSupported,
              _materialsSupported,
            ) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    model,
    technology,
    buildVolumeX,
    buildVolumeY,
    buildVolumeZ,
    connectorType,
    status,
    const DeepCollectionEquality().hash(_materialsSupported),
    lastSeenAt,
    createdAt,
  );

  /// Create a copy of Printer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterImplCopyWith<_$PrinterImpl> get copyWith =>
      __$$PrinterImplCopyWithImpl<_$PrinterImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterImplToJson(this);
  }
}

abstract class _Printer implements Printer {
  const factory _Printer({
    required final String id,
    required final String name,
    final String? model,
    required final PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') final double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') final double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') final double? buildVolumeZ,
    @JsonKey(name: 'connector_type')
    required final PrinterConnectorType connectorType,
    required final PrinterStatusValue status,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'last_seen_at') final DateTime? lastSeenAt,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$PrinterImpl;

  factory _Printer.fromJson(Map<String, dynamic> json) = _$PrinterImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get model;
  @override
  PrinterTechnology get technology;
  @override
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  PrinterConnectorType get connectorType;
  @override
  PrinterStatusValue get status;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported;
  @override
  @JsonKey(name: 'last_seen_at')
  DateTime? get lastSeenAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of Printer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterImplCopyWith<_$PrinterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PrinterCreate _$PrinterCreateFromJson(Map<String, dynamic> json) {
  return _PrinterCreate.fromJson(json);
}

/// @nodoc
mixin _$PrinterCreate {
  String get name => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  PrinterTechnology get technology => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ => throw _privateConstructorUsedError;
  @JsonKey(name: 'connector_type')
  PrinterConnectorType get connectorType => throw _privateConstructorUsedError;
  @JsonKey(name: 'connection_url')
  String? get connectionUrl => throw _privateConstructorUsedError;
  PrinterStatusValue get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported => throw _privateConstructorUsedError;
  @JsonKey(name: 'api_key')
  String? get apiKey => throw _privateConstructorUsedError;

  /// Serializes this PrinterCreate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrinterCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterCreateCopyWith<PrinterCreate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterCreateCopyWith<$Res> {
  factory $PrinterCreateCopyWith(
    PrinterCreate value,
    $Res Function(PrinterCreate) then,
  ) = _$PrinterCreateCopyWithImpl<$Res, PrinterCreate>;
  @useResult
  $Res call({
    String name,
    String? model,
    PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type') PrinterConnectorType connectorType,
    @JsonKey(name: 'connection_url') String? connectionUrl,
    PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'api_key') String? apiKey,
  });
}

/// @nodoc
class _$PrinterCreateCopyWithImpl<$Res, $Val extends PrinterCreate>
    implements $PrinterCreateCopyWith<$Res> {
  _$PrinterCreateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrinterCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? model = freezed,
    Object? technology = null,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = null,
    Object? connectionUrl = freezed,
    Object? status = null,
    Object? materialsSupported = freezed,
    Object? apiKey = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            technology: null == technology
                ? _value.technology
                : technology // ignore: cast_nullable_to_non_nullable
                      as PrinterTechnology,
            buildVolumeX: freezed == buildVolumeX
                ? _value.buildVolumeX
                : buildVolumeX // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeY: freezed == buildVolumeY
                ? _value.buildVolumeY
                : buildVolumeY // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeZ: freezed == buildVolumeZ
                ? _value.buildVolumeZ
                : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                      as double?,
            connectorType: null == connectorType
                ? _value.connectorType
                : connectorType // ignore: cast_nullable_to_non_nullable
                      as PrinterConnectorType,
            connectionUrl: freezed == connectionUrl
                ? _value.connectionUrl
                : connectionUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PrinterStatusValue,
            materialsSupported: freezed == materialsSupported
                ? _value.materialsSupported
                : materialsSupported // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            apiKey: freezed == apiKey
                ? _value.apiKey
                : apiKey // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterCreateImplCopyWith<$Res>
    implements $PrinterCreateCopyWith<$Res> {
  factory _$$PrinterCreateImplCopyWith(
    _$PrinterCreateImpl value,
    $Res Function(_$PrinterCreateImpl) then,
  ) = __$$PrinterCreateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String? model,
    PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') double? buildVolumeZ,
    @JsonKey(name: 'connector_type') PrinterConnectorType connectorType,
    @JsonKey(name: 'connection_url') String? connectionUrl,
    PrinterStatusValue status,
    @JsonKey(name: 'materials_supported') List<String>? materialsSupported,
    @JsonKey(name: 'api_key') String? apiKey,
  });
}

/// @nodoc
class __$$PrinterCreateImplCopyWithImpl<$Res>
    extends _$PrinterCreateCopyWithImpl<$Res, _$PrinterCreateImpl>
    implements _$$PrinterCreateImplCopyWith<$Res> {
  __$$PrinterCreateImplCopyWithImpl(
    _$PrinterCreateImpl _value,
    $Res Function(_$PrinterCreateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrinterCreate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? model = freezed,
    Object? technology = null,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = null,
    Object? connectionUrl = freezed,
    Object? status = null,
    Object? materialsSupported = freezed,
    Object? apiKey = freezed,
  }) {
    return _then(
      _$PrinterCreateImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        technology: null == technology
            ? _value.technology
            : technology // ignore: cast_nullable_to_non_nullable
                  as PrinterTechnology,
        buildVolumeX: freezed == buildVolumeX
            ? _value.buildVolumeX
            : buildVolumeX // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeY: freezed == buildVolumeY
            ? _value.buildVolumeY
            : buildVolumeY // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeZ: freezed == buildVolumeZ
            ? _value.buildVolumeZ
            : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                  as double?,
        connectorType: null == connectorType
            ? _value.connectorType
            : connectorType // ignore: cast_nullable_to_non_nullable
                  as PrinterConnectorType,
        connectionUrl: freezed == connectionUrl
            ? _value.connectionUrl
            : connectionUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PrinterStatusValue,
        materialsSupported: freezed == materialsSupported
            ? _value._materialsSupported
            : materialsSupported // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        apiKey: freezed == apiKey
            ? _value.apiKey
            : apiKey // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PrinterCreateImpl implements _PrinterCreate {
  const _$PrinterCreateImpl({
    required this.name,
    this.model,
    required this.technology,
    @JsonKey(name: 'build_volume_x') this.buildVolumeX,
    @JsonKey(name: 'build_volume_y') this.buildVolumeY,
    @JsonKey(name: 'build_volume_z') this.buildVolumeZ,
    @JsonKey(name: 'connector_type')
    this.connectorType = PrinterConnectorType.mock,
    @JsonKey(name: 'connection_url') this.connectionUrl,
    this.status = PrinterStatusValue.offline,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'api_key') this.apiKey,
  }) : _materialsSupported = materialsSupported;

  factory _$PrinterCreateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterCreateImplFromJson(json);

  @override
  final String name;
  @override
  final String? model;
  @override
  final PrinterTechnology technology;
  @override
  @JsonKey(name: 'build_volume_x')
  final double? buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  final double? buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  final double? buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  final PrinterConnectorType connectorType;
  @override
  @JsonKey(name: 'connection_url')
  final String? connectionUrl;
  @override
  @JsonKey()
  final PrinterStatusValue status;
  final List<String>? _materialsSupported;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported {
    final value = _materialsSupported;
    if (value == null) return null;
    if (_materialsSupported is EqualUnmodifiableListView)
      return _materialsSupported;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'api_key')
  final String? apiKey;

  @override
  String toString() {
    return 'PrinterCreate(name: $name, model: $model, technology: $technology, buildVolumeX: $buildVolumeX, buildVolumeY: $buildVolumeY, buildVolumeZ: $buildVolumeZ, connectorType: $connectorType, connectionUrl: $connectionUrl, status: $status, materialsSupported: $materialsSupported, apiKey: $apiKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterCreateImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.technology, technology) ||
                other.technology == technology) &&
            (identical(other.buildVolumeX, buildVolumeX) ||
                other.buildVolumeX == buildVolumeX) &&
            (identical(other.buildVolumeY, buildVolumeY) ||
                other.buildVolumeY == buildVolumeY) &&
            (identical(other.buildVolumeZ, buildVolumeZ) ||
                other.buildVolumeZ == buildVolumeZ) &&
            (identical(other.connectorType, connectorType) ||
                other.connectorType == connectorType) &&
            (identical(other.connectionUrl, connectionUrl) ||
                other.connectionUrl == connectionUrl) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._materialsSupported,
              _materialsSupported,
            ) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    model,
    technology,
    buildVolumeX,
    buildVolumeY,
    buildVolumeZ,
    connectorType,
    connectionUrl,
    status,
    const DeepCollectionEquality().hash(_materialsSupported),
    apiKey,
  );

  /// Create a copy of PrinterCreate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterCreateImplCopyWith<_$PrinterCreateImpl> get copyWith =>
      __$$PrinterCreateImplCopyWithImpl<_$PrinterCreateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterCreateImplToJson(this);
  }
}

abstract class _PrinterCreate implements PrinterCreate {
  const factory _PrinterCreate({
    required final String name,
    final String? model,
    required final PrinterTechnology technology,
    @JsonKey(name: 'build_volume_x') final double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') final double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') final double? buildVolumeZ,
    @JsonKey(name: 'connector_type') final PrinterConnectorType connectorType,
    @JsonKey(name: 'connection_url') final String? connectionUrl,
    final PrinterStatusValue status,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'api_key') final String? apiKey,
  }) = _$PrinterCreateImpl;

  factory _PrinterCreate.fromJson(Map<String, dynamic> json) =
      _$PrinterCreateImpl.fromJson;

  @override
  String get name;
  @override
  String? get model;
  @override
  PrinterTechnology get technology;
  @override
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  PrinterConnectorType get connectorType;
  @override
  @JsonKey(name: 'connection_url')
  String? get connectionUrl;
  @override
  PrinterStatusValue get status;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported;
  @override
  @JsonKey(name: 'api_key')
  String? get apiKey;

  /// Create a copy of PrinterCreate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterCreateImplCopyWith<_$PrinterCreateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PrinterUpdate _$PrinterUpdateFromJson(Map<String, dynamic> json) {
  return _PrinterUpdate.fromJson(json);
}

/// @nodoc
mixin _$PrinterUpdate {
  String? get name => throw _privateConstructorUsedError;
  String? get model => throw _privateConstructorUsedError;
  PrinterTechnology? get technology => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY => throw _privateConstructorUsedError;
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ => throw _privateConstructorUsedError;
  @JsonKey(name: 'connector_type')
  PrinterConnectorType? get connectorType => throw _privateConstructorUsedError;
  @JsonKey(name: 'connection_url')
  String? get connectionUrl => throw _privateConstructorUsedError;
  PrinterStatusValue? get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported => throw _privateConstructorUsedError;
  @JsonKey(name: 'api_key')
  String? get apiKey => throw _privateConstructorUsedError;

  /// Serializes this PrinterUpdate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrinterUpdate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterUpdateCopyWith<PrinterUpdate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterUpdateCopyWith<$Res> {
  factory $PrinterUpdateCopyWith(
    PrinterUpdate value,
    $Res Function(PrinterUpdate) then,
  ) = _$PrinterUpdateCopyWithImpl<$Res, PrinterUpdate>;
  @useResult
  $Res call({
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
  });
}

/// @nodoc
class _$PrinterUpdateCopyWithImpl<$Res, $Val extends PrinterUpdate>
    implements $PrinterUpdateCopyWith<$Res> {
  _$PrinterUpdateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrinterUpdate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? model = freezed,
    Object? technology = freezed,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = freezed,
    Object? connectionUrl = freezed,
    Object? status = freezed,
    Object? materialsSupported = freezed,
    Object? apiKey = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            model: freezed == model
                ? _value.model
                : model // ignore: cast_nullable_to_non_nullable
                      as String?,
            technology: freezed == technology
                ? _value.technology
                : technology // ignore: cast_nullable_to_non_nullable
                      as PrinterTechnology?,
            buildVolumeX: freezed == buildVolumeX
                ? _value.buildVolumeX
                : buildVolumeX // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeY: freezed == buildVolumeY
                ? _value.buildVolumeY
                : buildVolumeY // ignore: cast_nullable_to_non_nullable
                      as double?,
            buildVolumeZ: freezed == buildVolumeZ
                ? _value.buildVolumeZ
                : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                      as double?,
            connectorType: freezed == connectorType
                ? _value.connectorType
                : connectorType // ignore: cast_nullable_to_non_nullable
                      as PrinterConnectorType?,
            connectionUrl: freezed == connectionUrl
                ? _value.connectionUrl
                : connectionUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PrinterStatusValue?,
            materialsSupported: freezed == materialsSupported
                ? _value.materialsSupported
                : materialsSupported // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            apiKey: freezed == apiKey
                ? _value.apiKey
                : apiKey // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterUpdateImplCopyWith<$Res>
    implements $PrinterUpdateCopyWith<$Res> {
  factory _$$PrinterUpdateImplCopyWith(
    _$PrinterUpdateImpl value,
    $Res Function(_$PrinterUpdateImpl) then,
  ) = __$$PrinterUpdateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
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
  });
}

/// @nodoc
class __$$PrinterUpdateImplCopyWithImpl<$Res>
    extends _$PrinterUpdateCopyWithImpl<$Res, _$PrinterUpdateImpl>
    implements _$$PrinterUpdateImplCopyWith<$Res> {
  __$$PrinterUpdateImplCopyWithImpl(
    _$PrinterUpdateImpl _value,
    $Res Function(_$PrinterUpdateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrinterUpdate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? model = freezed,
    Object? technology = freezed,
    Object? buildVolumeX = freezed,
    Object? buildVolumeY = freezed,
    Object? buildVolumeZ = freezed,
    Object? connectorType = freezed,
    Object? connectionUrl = freezed,
    Object? status = freezed,
    Object? materialsSupported = freezed,
    Object? apiKey = freezed,
  }) {
    return _then(
      _$PrinterUpdateImpl(
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        model: freezed == model
            ? _value.model
            : model // ignore: cast_nullable_to_non_nullable
                  as String?,
        technology: freezed == technology
            ? _value.technology
            : technology // ignore: cast_nullable_to_non_nullable
                  as PrinterTechnology?,
        buildVolumeX: freezed == buildVolumeX
            ? _value.buildVolumeX
            : buildVolumeX // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeY: freezed == buildVolumeY
            ? _value.buildVolumeY
            : buildVolumeY // ignore: cast_nullable_to_non_nullable
                  as double?,
        buildVolumeZ: freezed == buildVolumeZ
            ? _value.buildVolumeZ
            : buildVolumeZ // ignore: cast_nullable_to_non_nullable
                  as double?,
        connectorType: freezed == connectorType
            ? _value.connectorType
            : connectorType // ignore: cast_nullable_to_non_nullable
                  as PrinterConnectorType?,
        connectionUrl: freezed == connectionUrl
            ? _value.connectionUrl
            : connectionUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PrinterStatusValue?,
        materialsSupported: freezed == materialsSupported
            ? _value._materialsSupported
            : materialsSupported // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        apiKey: freezed == apiKey
            ? _value.apiKey
            : apiKey // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _$PrinterUpdateImpl implements _PrinterUpdate {
  const _$PrinterUpdateImpl({
    this.name,
    this.model,
    this.technology,
    @JsonKey(name: 'build_volume_x') this.buildVolumeX,
    @JsonKey(name: 'build_volume_y') this.buildVolumeY,
    @JsonKey(name: 'build_volume_z') this.buildVolumeZ,
    @JsonKey(name: 'connector_type') this.connectorType,
    @JsonKey(name: 'connection_url') this.connectionUrl,
    this.status,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'api_key') this.apiKey,
  }) : _materialsSupported = materialsSupported;

  factory _$PrinterUpdateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterUpdateImplFromJson(json);

  @override
  final String? name;
  @override
  final String? model;
  @override
  final PrinterTechnology? technology;
  @override
  @JsonKey(name: 'build_volume_x')
  final double? buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  final double? buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  final double? buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  final PrinterConnectorType? connectorType;
  @override
  @JsonKey(name: 'connection_url')
  final String? connectionUrl;
  @override
  final PrinterStatusValue? status;
  final List<String>? _materialsSupported;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported {
    final value = _materialsSupported;
    if (value == null) return null;
    if (_materialsSupported is EqualUnmodifiableListView)
      return _materialsSupported;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'api_key')
  final String? apiKey;

  @override
  String toString() {
    return 'PrinterUpdate(name: $name, model: $model, technology: $technology, buildVolumeX: $buildVolumeX, buildVolumeY: $buildVolumeY, buildVolumeZ: $buildVolumeZ, connectorType: $connectorType, connectionUrl: $connectionUrl, status: $status, materialsSupported: $materialsSupported, apiKey: $apiKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterUpdateImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.technology, technology) ||
                other.technology == technology) &&
            (identical(other.buildVolumeX, buildVolumeX) ||
                other.buildVolumeX == buildVolumeX) &&
            (identical(other.buildVolumeY, buildVolumeY) ||
                other.buildVolumeY == buildVolumeY) &&
            (identical(other.buildVolumeZ, buildVolumeZ) ||
                other.buildVolumeZ == buildVolumeZ) &&
            (identical(other.connectorType, connectorType) ||
                other.connectorType == connectorType) &&
            (identical(other.connectionUrl, connectionUrl) ||
                other.connectionUrl == connectionUrl) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(
              other._materialsSupported,
              _materialsSupported,
            ) &&
            (identical(other.apiKey, apiKey) || other.apiKey == apiKey));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    model,
    technology,
    buildVolumeX,
    buildVolumeY,
    buildVolumeZ,
    connectorType,
    connectionUrl,
    status,
    const DeepCollectionEquality().hash(_materialsSupported),
    apiKey,
  );

  /// Create a copy of PrinterUpdate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterUpdateImplCopyWith<_$PrinterUpdateImpl> get copyWith =>
      __$$PrinterUpdateImplCopyWithImpl<_$PrinterUpdateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterUpdateImplToJson(this);
  }
}

abstract class _PrinterUpdate implements PrinterUpdate {
  const factory _PrinterUpdate({
    final String? name,
    final String? model,
    final PrinterTechnology? technology,
    @JsonKey(name: 'build_volume_x') final double? buildVolumeX,
    @JsonKey(name: 'build_volume_y') final double? buildVolumeY,
    @JsonKey(name: 'build_volume_z') final double? buildVolumeZ,
    @JsonKey(name: 'connector_type') final PrinterConnectorType? connectorType,
    @JsonKey(name: 'connection_url') final String? connectionUrl,
    final PrinterStatusValue? status,
    @JsonKey(name: 'materials_supported')
    final List<String>? materialsSupported,
    @JsonKey(name: 'api_key') final String? apiKey,
  }) = _$PrinterUpdateImpl;

  factory _PrinterUpdate.fromJson(Map<String, dynamic> json) =
      _$PrinterUpdateImpl.fromJson;

  @override
  String? get name;
  @override
  String? get model;
  @override
  PrinterTechnology? get technology;
  @override
  @JsonKey(name: 'build_volume_x')
  double? get buildVolumeX;
  @override
  @JsonKey(name: 'build_volume_y')
  double? get buildVolumeY;
  @override
  @JsonKey(name: 'build_volume_z')
  double? get buildVolumeZ;
  @override
  @JsonKey(name: 'connector_type')
  PrinterConnectorType? get connectorType;
  @override
  @JsonKey(name: 'connection_url')
  String? get connectionUrl;
  @override
  PrinterStatusValue? get status;
  @override
  @JsonKey(name: 'materials_supported')
  List<String>? get materialsSupported;
  @override
  @JsonKey(name: 'api_key')
  String? get apiKey;

  /// Create a copy of PrinterUpdate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterUpdateImplCopyWith<_$PrinterUpdateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
