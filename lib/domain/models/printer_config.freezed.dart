// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'printer_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PrinterConfig _$PrinterConfigFromJson(Map<String, dynamic> json) {
  return _PrinterConfig.fromJson(json);
}

/// @nodoc
mixin _$PrinterConfig {
  PrinterConnectionType get connectionType =>
      throw _privateConstructorUsedError;
  PrinterPaperSize get paperSize => throw _privateConstructorUsedError;
  String? get address =>
      throw _privateConstructorUsedError; // Mac address for BT, IP for Network, VendorID/ProductID for USB
  int get port => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  bool get autoPrintKOT => throw _privateConstructorUsedError;
  bool get autoPrintBill => throw _privateConstructorUsedError;
  bool get isBle => throw _privateConstructorUsedError;

  /// Serializes this PrinterConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PrinterConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PrinterConfigCopyWith<PrinterConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PrinterConfigCopyWith<$Res> {
  factory $PrinterConfigCopyWith(
    PrinterConfig value,
    $Res Function(PrinterConfig) then,
  ) = _$PrinterConfigCopyWithImpl<$Res, PrinterConfig>;
  @useResult
  $Res call({
    PrinterConnectionType connectionType,
    PrinterPaperSize paperSize,
    String? address,
    int port,
    String name,
    bool autoPrintKOT,
    bool autoPrintBill,
    bool isBle,
  });
}

/// @nodoc
class _$PrinterConfigCopyWithImpl<$Res, $Val extends PrinterConfig>
    implements $PrinterConfigCopyWith<$Res> {
  _$PrinterConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PrinterConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? connectionType = null,
    Object? paperSize = null,
    Object? address = freezed,
    Object? port = null,
    Object? name = null,
    Object? autoPrintKOT = null,
    Object? autoPrintBill = null,
    Object? isBle = null,
  }) {
    return _then(
      _value.copyWith(
            connectionType: null == connectionType
                ? _value.connectionType
                : connectionType // ignore: cast_nullable_to_non_nullable
                      as PrinterConnectionType,
            paperSize: null == paperSize
                ? _value.paperSize
                : paperSize // ignore: cast_nullable_to_non_nullable
                      as PrinterPaperSize,
            address: freezed == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String?,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            autoPrintKOT: null == autoPrintKOT
                ? _value.autoPrintKOT
                : autoPrintKOT // ignore: cast_nullable_to_non_nullable
                      as bool,
            autoPrintBill: null == autoPrintBill
                ? _value.autoPrintBill
                : autoPrintBill // ignore: cast_nullable_to_non_nullable
                      as bool,
            isBle: null == isBle
                ? _value.isBle
                : isBle // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PrinterConfigImplCopyWith<$Res>
    implements $PrinterConfigCopyWith<$Res> {
  factory _$$PrinterConfigImplCopyWith(
    _$PrinterConfigImpl value,
    $Res Function(_$PrinterConfigImpl) then,
  ) = __$$PrinterConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    PrinterConnectionType connectionType,
    PrinterPaperSize paperSize,
    String? address,
    int port,
    String name,
    bool autoPrintKOT,
    bool autoPrintBill,
    bool isBle,
  });
}

/// @nodoc
class __$$PrinterConfigImplCopyWithImpl<$Res>
    extends _$PrinterConfigCopyWithImpl<$Res, _$PrinterConfigImpl>
    implements _$$PrinterConfigImplCopyWith<$Res> {
  __$$PrinterConfigImplCopyWithImpl(
    _$PrinterConfigImpl _value,
    $Res Function(_$PrinterConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PrinterConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? connectionType = null,
    Object? paperSize = null,
    Object? address = freezed,
    Object? port = null,
    Object? name = null,
    Object? autoPrintKOT = null,
    Object? autoPrintBill = null,
    Object? isBle = null,
  }) {
    return _then(
      _$PrinterConfigImpl(
        connectionType: null == connectionType
            ? _value.connectionType
            : connectionType // ignore: cast_nullable_to_non_nullable
                  as PrinterConnectionType,
        paperSize: null == paperSize
            ? _value.paperSize
            : paperSize // ignore: cast_nullable_to_non_nullable
                  as PrinterPaperSize,
        address: freezed == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String?,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        autoPrintKOT: null == autoPrintKOT
            ? _value.autoPrintKOT
            : autoPrintKOT // ignore: cast_nullable_to_non_nullable
                  as bool,
        autoPrintBill: null == autoPrintBill
            ? _value.autoPrintBill
            : autoPrintBill // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBle: null == isBle
            ? _value.isBle
            : isBle // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PrinterConfigImpl implements _PrinterConfig {
  const _$PrinterConfigImpl({
    this.connectionType = PrinterConnectionType.rawbt,
    this.paperSize = PrinterPaperSize.mm58,
    this.address,
    this.port = 9100,
    this.name = 'Default Printer',
    this.autoPrintKOT = true,
    this.autoPrintBill = true,
    this.isBle = false,
  });

  factory _$PrinterConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$PrinterConfigImplFromJson(json);

  @override
  @JsonKey()
  final PrinterConnectionType connectionType;
  @override
  @JsonKey()
  final PrinterPaperSize paperSize;
  @override
  final String? address;
  // Mac address for BT, IP for Network, VendorID/ProductID for USB
  @override
  @JsonKey()
  final int port;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final bool autoPrintKOT;
  @override
  @JsonKey()
  final bool autoPrintBill;
  @override
  @JsonKey()
  final bool isBle;

  @override
  String toString() {
    return 'PrinterConfig(connectionType: $connectionType, paperSize: $paperSize, address: $address, port: $port, name: $name, autoPrintKOT: $autoPrintKOT, autoPrintBill: $autoPrintBill, isBle: $isBle)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PrinterConfigImpl &&
            (identical(other.connectionType, connectionType) ||
                other.connectionType == connectionType) &&
            (identical(other.paperSize, paperSize) ||
                other.paperSize == paperSize) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.autoPrintKOT, autoPrintKOT) ||
                other.autoPrintKOT == autoPrintKOT) &&
            (identical(other.autoPrintBill, autoPrintBill) ||
                other.autoPrintBill == autoPrintBill) &&
            (identical(other.isBle, isBle) || other.isBle == isBle));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    connectionType,
    paperSize,
    address,
    port,
    name,
    autoPrintKOT,
    autoPrintBill,
    isBle,
  );

  /// Create a copy of PrinterConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PrinterConfigImplCopyWith<_$PrinterConfigImpl> get copyWith =>
      __$$PrinterConfigImplCopyWithImpl<_$PrinterConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PrinterConfigImplToJson(this);
  }
}

abstract class _PrinterConfig implements PrinterConfig {
  const factory _PrinterConfig({
    final PrinterConnectionType connectionType,
    final PrinterPaperSize paperSize,
    final String? address,
    final int port,
    final String name,
    final bool autoPrintKOT,
    final bool autoPrintBill,
    final bool isBle,
  }) = _$PrinterConfigImpl;

  factory _PrinterConfig.fromJson(Map<String, dynamic> json) =
      _$PrinterConfigImpl.fromJson;

  @override
  PrinterConnectionType get connectionType;
  @override
  PrinterPaperSize get paperSize;
  @override
  String? get address; // Mac address for BT, IP for Network, VendorID/ProductID for USB
  @override
  int get port;
  @override
  String get name;
  @override
  bool get autoPrintKOT;
  @override
  bool get autoPrintBill;
  @override
  bool get isBle;

  /// Create a copy of PrinterConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PrinterConfigImplCopyWith<_$PrinterConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
