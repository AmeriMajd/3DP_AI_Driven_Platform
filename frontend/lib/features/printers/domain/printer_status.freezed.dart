// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'printer_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PrinterStatus _$PrinterStatusFromJson(Map<String, dynamic> json) {
  return _PrinterStatus.fromJson(json);
}

/// @nodoc
mixin _$PrinterStatus {
  @JsonKey(name: 'printer_id')
  String get printerId => throw _privateConstructorUsedError;
  PrinterStatusValue get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'current_job_id')
  String? get currentJobId => throw _privateConstructorUsedError;
  @JsonKey(name: 'progress_pct')
  double? get progressPct => throw _privateConstructorUsedError;
  @JsonKey(name: 'temperature_nozzle')
  double? get temperatureNozzle => throw _privateConstructorUsedError;
  @JsonKey(name: 'temperature_bed')
  double? get temperatureBed => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_seen_at')
  DateTime? get lastSeenAt => throw _privateConstructorUsedError;

  /// Serializes this PrinterStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrinterStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterStatusCopyWith<PrinterStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterStatusCopyWith<$Res> {
  factory $PrinterStatusCopyWith(
    PrinterStatus value,
    $Res Function(PrinterStatus) then,
  ) = _$PrinterStatusCopyWithImpl<$Res, PrinterStatus>;
  @useResult
  $Res call({
    @JsonKey(name: 'printer_id') String printerId,
    PrinterStatusValue status,
    @JsonKey(name: 'current_job_id') String? currentJobId,
    @JsonKey(name: 'progress_pct') double? progressPct,
    @JsonKey(name: 'temperature_nozzle') double? temperatureNozzle,
    @JsonKey(name: 'temperature_bed') double? temperatureBed,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
  });
}

/// @nodoc
class _$PrinterStatusCopyWithImpl<$Res, $Val extends PrinterStatus>
    implements $PrinterStatusCopyWith<$Res> {
  _$PrinterStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrinterStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? printerId = null,
    Object? status = null,
    Object? currentJobId = freezed,
    Object? progressPct = freezed,
    Object? temperatureNozzle = freezed,
    Object? temperatureBed = freezed,
    Object? lastSeenAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            printerId: null == printerId
                ? _value.printerId
                : printerId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PrinterStatusValue,
            currentJobId: freezed == currentJobId
                ? _value.currentJobId
                : currentJobId // ignore: cast_nullable_to_non_nullable
                      as String?,
            progressPct: freezed == progressPct
                ? _value.progressPct
                : progressPct // ignore: cast_nullable_to_non_nullable
                      as double?,
            temperatureNozzle: freezed == temperatureNozzle
                ? _value.temperatureNozzle
                : temperatureNozzle // ignore: cast_nullable_to_non_nullable
                      as double?,
            temperatureBed: freezed == temperatureBed
                ? _value.temperatureBed
                : temperatureBed // ignore: cast_nullable_to_non_nullable
                      as double?,
            lastSeenAt: freezed == lastSeenAt
                ? _value.lastSeenAt
                : lastSeenAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterStatusImplCopyWith<$Res>
    implements $PrinterStatusCopyWith<$Res> {
  factory _$$PrinterStatusImplCopyWith(
    _$PrinterStatusImpl value,
    $Res Function(_$PrinterStatusImpl) then,
  ) = __$$PrinterStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'printer_id') String printerId,
    PrinterStatusValue status,
    @JsonKey(name: 'current_job_id') String? currentJobId,
    @JsonKey(name: 'progress_pct') double? progressPct,
    @JsonKey(name: 'temperature_nozzle') double? temperatureNozzle,
    @JsonKey(name: 'temperature_bed') double? temperatureBed,
    @JsonKey(name: 'last_seen_at') DateTime? lastSeenAt,
  });
}

/// @nodoc
class __$$PrinterStatusImplCopyWithImpl<$Res>
    extends _$PrinterStatusCopyWithImpl<$Res, _$PrinterStatusImpl>
    implements _$$PrinterStatusImplCopyWith<$Res> {
  __$$PrinterStatusImplCopyWithImpl(
    _$PrinterStatusImpl _value,
    $Res Function(_$PrinterStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrinterStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? printerId = null,
    Object? status = null,
    Object? currentJobId = freezed,
    Object? progressPct = freezed,
    Object? temperatureNozzle = freezed,
    Object? temperatureBed = freezed,
    Object? lastSeenAt = freezed,
  }) {
    return _then(
      _$PrinterStatusImpl(
        printerId: null == printerId
            ? _value.printerId
            : printerId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PrinterStatusValue,
        currentJobId: freezed == currentJobId
            ? _value.currentJobId
            : currentJobId // ignore: cast_nullable_to_non_nullable
                  as String?,
        progressPct: freezed == progressPct
            ? _value.progressPct
            : progressPct // ignore: cast_nullable_to_non_nullable
                  as double?,
        temperatureNozzle: freezed == temperatureNozzle
            ? _value.temperatureNozzle
            : temperatureNozzle // ignore: cast_nullable_to_non_nullable
                  as double?,
        temperatureBed: freezed == temperatureBed
            ? _value.temperatureBed
            : temperatureBed // ignore: cast_nullable_to_non_nullable
                  as double?,
        lastSeenAt: freezed == lastSeenAt
            ? _value.lastSeenAt
            : lastSeenAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PrinterStatusImpl implements _PrinterStatus {
  const _$PrinterStatusImpl({
    @JsonKey(name: 'printer_id') required this.printerId,
    required this.status,
    @JsonKey(name: 'current_job_id') this.currentJobId,
    @JsonKey(name: 'progress_pct') this.progressPct,
    @JsonKey(name: 'temperature_nozzle') this.temperatureNozzle,
    @JsonKey(name: 'temperature_bed') this.temperatureBed,
    @JsonKey(name: 'last_seen_at') this.lastSeenAt,
  });

  factory _$PrinterStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterStatusImplFromJson(json);

  @override
  @JsonKey(name: 'printer_id')
  final String printerId;
  @override
  final PrinterStatusValue status;
  @override
  @JsonKey(name: 'current_job_id')
  final String? currentJobId;
  @override
  @JsonKey(name: 'progress_pct')
  final double? progressPct;
  @override
  @JsonKey(name: 'temperature_nozzle')
  final double? temperatureNozzle;
  @override
  @JsonKey(name: 'temperature_bed')
  final double? temperatureBed;
  @override
  @JsonKey(name: 'last_seen_at')
  final DateTime? lastSeenAt;

  @override
  String toString() {
    return 'PrinterStatus(printerId: $printerId, status: $status, currentJobId: $currentJobId, progressPct: $progressPct, temperatureNozzle: $temperatureNozzle, temperatureBed: $temperatureBed, lastSeenAt: $lastSeenAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterStatusImpl &&
            (identical(other.printerId, printerId) ||
                other.printerId == printerId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.currentJobId, currentJobId) ||
                other.currentJobId == currentJobId) &&
            (identical(other.progressPct, progressPct) ||
                other.progressPct == progressPct) &&
            (identical(other.temperatureNozzle, temperatureNozzle) ||
                other.temperatureNozzle == temperatureNozzle) &&
            (identical(other.temperatureBed, temperatureBed) ||
                other.temperatureBed == temperatureBed) &&
            (identical(other.lastSeenAt, lastSeenAt) ||
                other.lastSeenAt == lastSeenAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    printerId,
    status,
    currentJobId,
    progressPct,
    temperatureNozzle,
    temperatureBed,
    lastSeenAt,
  );

  /// Create a copy of PrinterStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterStatusImplCopyWith<_$PrinterStatusImpl> get copyWith =>
      __$$PrinterStatusImplCopyWithImpl<_$PrinterStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterStatusImplToJson(this);
  }
}

abstract class _PrinterStatus implements PrinterStatus {
  const factory _PrinterStatus({
    @JsonKey(name: 'printer_id') required final String printerId,
    required final PrinterStatusValue status,
    @JsonKey(name: 'current_job_id') final String? currentJobId,
    @JsonKey(name: 'progress_pct') final double? progressPct,
    @JsonKey(name: 'temperature_nozzle') final double? temperatureNozzle,
    @JsonKey(name: 'temperature_bed') final double? temperatureBed,
    @JsonKey(name: 'last_seen_at') final DateTime? lastSeenAt,
  }) = _$PrinterStatusImpl;

  factory _PrinterStatus.fromJson(Map<String, dynamic> json) =
      _$PrinterStatusImpl.fromJson;

  @override
  @JsonKey(name: 'printer_id')
  String get printerId;
  @override
  PrinterStatusValue get status;
  @override
  @JsonKey(name: 'current_job_id')
  String? get currentJobId;
  @override
  @JsonKey(name: 'progress_pct')
  double? get progressPct;
  @override
  @JsonKey(name: 'temperature_nozzle')
  double? get temperatureNozzle;
  @override
  @JsonKey(name: 'temperature_bed')
  double? get temperatureBed;
  @override
  @JsonKey(name: 'last_seen_at')
  DateTime? get lastSeenAt;

  /// Create a copy of PrinterStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterStatusImplCopyWith<_$PrinterStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PrinterTestResult _$PrinterTestResultFromJson(Map<String, dynamic> json) {
  return _PrinterTestResult.fromJson(json);
}

/// @nodoc
mixin _$PrinterTestResult {
  @JsonKey(name: 'printer_id')
  String get printerId => throw _privateConstructorUsedError;
  bool get ok => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;

  /// Serializes this PrinterTestResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrinterTestResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterTestResultCopyWith<PrinterTestResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterTestResultCopyWith<$Res> {
  factory $PrinterTestResultCopyWith(
    PrinterTestResult value,
    $Res Function(PrinterTestResult) then,
  ) = _$PrinterTestResultCopyWithImpl<$Res, PrinterTestResult>;
  @useResult
  $Res call({
    @JsonKey(name: 'printer_id') String printerId,
    bool ok,
    String message,
  });
}

/// @nodoc
class _$PrinterTestResultCopyWithImpl<$Res, $Val extends PrinterTestResult>
    implements $PrinterTestResultCopyWith<$Res> {
  _$PrinterTestResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrinterTestResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? printerId = null,
    Object? ok = null,
    Object? message = null,
  }) {
    return _then(
      _value.copyWith(
            printerId: null == printerId
                ? _value.printerId
                : printerId // ignore: cast_nullable_to_non_nullable
                      as String,
            ok: null == ok
                ? _value.ok
                : ok // ignore: cast_nullable_to_non_nullable
                      as bool,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterTestResultImplCopyWith<$Res>
    implements $PrinterTestResultCopyWith<$Res> {
  factory _$$PrinterTestResultImplCopyWith(
    _$PrinterTestResultImpl value,
    $Res Function(_$PrinterTestResultImpl) then,
  ) = __$$PrinterTestResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'printer_id') String printerId,
    bool ok,
    String message,
  });
}

/// @nodoc
class __$$PrinterTestResultImplCopyWithImpl<$Res>
    extends _$PrinterTestResultCopyWithImpl<$Res, _$PrinterTestResultImpl>
    implements _$$PrinterTestResultImplCopyWith<$Res> {
  __$$PrinterTestResultImplCopyWithImpl(
    _$PrinterTestResultImpl _value,
    $Res Function(_$PrinterTestResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrinterTestResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? printerId = null,
    Object? ok = null,
    Object? message = null,
  }) {
    return _then(
      _$PrinterTestResultImpl(
        printerId: null == printerId
            ? _value.printerId
            : printerId // ignore: cast_nullable_to_non_nullable
                  as String,
        ok: null == ok
            ? _value.ok
            : ok // ignore: cast_nullable_to_non_nullable
                  as bool,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PrinterTestResultImpl implements _PrinterTestResult {
  const _$PrinterTestResultImpl({
    @JsonKey(name: 'printer_id') required this.printerId,
    required this.ok,
    required this.message,
  });

  factory _$PrinterTestResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterTestResultImplFromJson(json);

  @override
  @JsonKey(name: 'printer_id')
  final String printerId;
  @override
  final bool ok;
  @override
  final String message;

  @override
  String toString() {
    return 'PrinterTestResult(printerId: $printerId, ok: $ok, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterTestResultImpl &&
            (identical(other.printerId, printerId) ||
                other.printerId == printerId) &&
            (identical(other.ok, ok) || other.ok == ok) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, printerId, ok, message);

  /// Create a copy of PrinterTestResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterTestResultImplCopyWith<_$PrinterTestResultImpl> get copyWith =>
      __$$PrinterTestResultImplCopyWithImpl<_$PrinterTestResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterTestResultImplToJson(this);
  }
}

abstract class _PrinterTestResult implements PrinterTestResult {
  const factory _PrinterTestResult({
    @JsonKey(name: 'printer_id') required final String printerId,
    required final bool ok,
    required final String message,
  }) = _$PrinterTestResultImpl;

  factory _PrinterTestResult.fromJson(Map<String, dynamic> json) =
      _$PrinterTestResultImpl.fromJson;

  @override
  @JsonKey(name: 'printer_id')
  String get printerId;
  @override
  bool get ok;
  @override
  String get message;

  /// Create a copy of PrinterTestResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterTestResultImplCopyWith<_$PrinterTestResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
