// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BillItemImpl _$$BillItemImplFromJson(Map<String, dynamic> json) =>
    _$BillItemImpl(
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      qty: (json['qty'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      note: json['note'] as String? ?? '',
    );

Map<String, dynamic> _$$BillItemImplToJson(_$BillItemImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'category': instance.category,
      'qty': instance.qty,
      'price': instance.price,
      'note': instance.note,
    };

_$PaymentImpl _$$PaymentImplFromJson(Map<String, dynamic> json) =>
    _$PaymentImpl(
      mode: json['mode'] as String,
      amount: (json['amount'] as num).toDouble(),
    );

Map<String, dynamic> _$$PaymentImplToJson(_$PaymentImpl instance) =>
    <String, dynamic>{'mode': instance.mode, 'amount': instance.amount};

_$BillModelImpl _$$BillModelImplFromJson(Map<String, dynamic> json) =>
    _$BillModelImpl(
      billId: json['billId'] as String,
      orderId: json['orderId'] as String,
      tableId: json['tableId'] as String,
      tableName: json['tableName'] as String,
      userName: json['userName'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discountType'] as String? ?? 'percent',
      extraCharges: (json['extraCharges'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      payments: (json['payments'] as List<dynamic>)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
      printCount: (json['printCount'] as num?)?.toInt() ?? 1,
      isSuspicious: json['isSuspicious'] as bool? ?? false,
      createdBy: json['createdBy'] as String,
      createdAt: const TimestampConverter().fromJson(json['createdAt']),
      printedAt: const OptionalTimestampConverter().fromJson(json['printedAt']),
      lastPrintedBy: json['lastPrintedBy'] as String?,
      isVoided: json['isVoided'] as bool? ?? false,
      voidedAt: const OptionalTimestampConverter().fromJson(json['voidedAt']),
      voidedBy: json['voidedBy'] as String?,
      voidReason: json['voidReason'] as String?,
      tableRestored: json['tableRestored'] as bool? ?? false,
    );

Map<String, dynamic> _$$BillModelImplToJson(
  _$BillModelImpl instance,
) => <String, dynamic>{
  'billId': instance.billId,
  'orderId': instance.orderId,
  'tableId': instance.tableId,
  'tableName': instance.tableName,
  'userName': instance.userName,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'subtotal': instance.subtotal,
  'discountPercent': instance.discountPercent,
  'discountAmount': instance.discountAmount,
  'discountType': instance.discountType,
  'extraCharges': instance.extraCharges,
  'total': instance.total,
  'payments': instance.payments.map((e) => e.toJson()).toList(),
  'printCount': instance.printCount,
  'isSuspicious': instance.isSuspicious,
  'createdBy': instance.createdBy,
  'createdAt': const TimestampConverter().toJson(instance.createdAt),
  'printedAt': const OptionalTimestampConverter().toJson(instance.printedAt),
  'lastPrintedBy': instance.lastPrintedBy,
  'isVoided': instance.isVoided,
  'voidedAt': const OptionalTimestampConverter().toJson(instance.voidedAt),
  'voidedBy': instance.voidedBy,
  'voidReason': instance.voidReason,
  'tableRestored': instance.tableRestored,
};
