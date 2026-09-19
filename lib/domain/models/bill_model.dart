import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/timestamp_converter.dart';

part 'bill_model.freezed.dart';
part 'bill_model.g.dart';

@freezed
class BillItem with _$BillItem {
  const factory BillItem({
    required String name,
    @Default('') String category,
    required int qty,
    required double price,
    @Default('') String note,
  }) = _BillItem;

  factory BillItem.fromJson(Map<String, dynamic> json) => _$BillItemFromJson(json);
}

@freezed
class Payment with _$Payment {
  const factory Payment({
    required String mode, // cash | upi | card
    required double amount,
  }) = _Payment;

  factory Payment.fromJson(Map<String, dynamic> json) => _$PaymentFromJson(json);
}

@freezed
class BillModel with _$BillModel {
  const factory BillModel({
    required String billId,
    required String orderId,
    required String tableId,
    required String tableName,
    required String userName,
    required List<BillItem> items,
    required double subtotal,
    @Default(0.0) double discountPercent,
    @Default(0.0) double discountAmount,
    @Default('percent') String discountType,
    @Default(0.0) double extraCharges,
    required double total,
    required List<Payment> payments,
    @Default(1) int printCount,
    @Default(false) bool isSuspicious,
    required String createdBy,
    @TimestampConverter() required DateTime createdAt,
    @OptionalTimestampConverter() DateTime? printedAt,
    String? lastPrintedBy,
    @Default(false) bool isVoided,
    @OptionalTimestampConverter() DateTime? voidedAt,
    String? voidedBy,
    String? voidReason,
    @Default(false) bool tableRestored,
  }) = _BillModel;

  factory BillModel.fromJson(Map<String, dynamic> json) => _$BillModelFromJson(json);
}
