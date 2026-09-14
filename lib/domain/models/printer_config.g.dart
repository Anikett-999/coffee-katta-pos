// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PrinterConfigImpl _$$PrinterConfigImplFromJson(Map<String, dynamic> json) =>
    _$PrinterConfigImpl(
      connectionType:
          $enumDecodeNullable(
            _$PrinterConnectionTypeEnumMap,
            json['connectionType'],
          ) ??
          PrinterConnectionType.rawbt,
      paperSize:
          $enumDecodeNullable(_$PrinterPaperSizeEnumMap, json['paperSize']) ??
          PrinterPaperSize.mm58,
      address: json['address'] as String?,
      port: (json['port'] as num?)?.toInt() ?? 9100,
      name: json['name'] as String? ?? 'Default Printer',
      autoPrintKOT: json['autoPrintKOT'] as bool? ?? true,
      autoPrintBill: json['autoPrintBill'] as bool? ?? true,
      isBle: json['isBle'] as bool? ?? false,
    );

Map<String, dynamic> _$$PrinterConfigImplToJson(
  _$PrinterConfigImpl instance,
) => <String, dynamic>{
  'connectionType': _$PrinterConnectionTypeEnumMap[instance.connectionType]!,
  'paperSize': _$PrinterPaperSizeEnumMap[instance.paperSize]!,
  'address': instance.address,
  'port': instance.port,
  'name': instance.name,
  'autoPrintKOT': instance.autoPrintKOT,
  'autoPrintBill': instance.autoPrintBill,
  'isBle': instance.isBle,
};

const _$PrinterConnectionTypeEnumMap = {
  PrinterConnectionType.bluetooth: 'bluetooth',
  PrinterConnectionType.usb: 'usb',
  PrinterConnectionType.network: 'network',
  PrinterConnectionType.rawbt: 'rawbt',
};

const _$PrinterPaperSizeEnumMap = {
  PrinterPaperSize.mm58: 'mm58',
  PrinterPaperSize.mm80: 'mm80',
};
