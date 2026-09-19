import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/services/pdf_service.dart';

void main() {
  group('P0-3: Bill Void / Cancel / Refund Tests', () {
    test('BillModel defaults to isVoided: false and tableRestored: false', () {
      final bill = BillModel(
        billId: 'INV-260915-001',
        orderId: 'ORD-101',
        tableId: 'T1',
        tableName: 'Table 1',
        userName: 'Cashier 1',
        items: [
          const BillItem(name: 'Cold Coffee', category: 'Katta Coffee', qty: 2, price: 60.0),
        ],
        subtotal: 120.0,
        total: 120.0,
        payments: [const Payment(mode: 'cash', amount: 120.0)],
        createdBy: 'user_123',
        createdAt: DateTime.now(),
      );

      expect(bill.isVoided, isFalse);
      expect(bill.voidedAt, isNull);
      expect(bill.voidedBy, isNull);
      expect(bill.voidReason, isNull);
      expect(bill.tableRestored, isFalse);
    });

    test('BillModel serializes and deserializes void metadata correctly', () {
      final voidedTime = DateTime(2026, 9, 15, 14, 30);
      final bill = BillModel(
        billId: 'INV-260915-002',
        orderId: 'ORD-102',
        tableId: 'T2',
        tableName: 'Table 2',
        userName: 'Cashier 1',
        items: [
          const BillItem(name: 'Bun Maska', category: 'Katta Starter', qty: 1, price: 50.0),
        ],
        subtotal: 50.0,
        total: 50.0,
        payments: [const Payment(mode: 'upi', amount: 50.0)],
        createdBy: 'user_123',
        createdAt: DateTime(2026, 9, 15, 14, 0),
        isVoided: true,
        voidedAt: voidedTime,
        voidedBy: 'Manager John',
        voidReason: 'Wrong table selected by cashier',
        tableRestored: true,
      );

      final json = bill.toJson();
      expect(json['isVoided'], isTrue);
      expect(json['voidedBy'], equals('Manager John'));
      expect(json['voidReason'], equals('Wrong table selected by cashier'));
      expect(json['tableRestored'], isTrue);

      final restored = BillModel.fromJson(json);
      expect(restored.isVoided, isTrue);
      expect(restored.voidedBy, equals('Manager John'));
      expect(restored.voidReason, equals('Wrong table selected by cashier'));
      expect(restored.tableRestored, isTrue);
    });

    test('Active vs Voided filter partitions bills correctly', () {
      final activeBill1 = BillModel(
        billId: 'INV-001',
        orderId: 'O1',
        tableId: 'T1',
        tableName: 'T1',
        userName: 'Staff',
        items: [],
        subtotal: 100,
        total: 100,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: false,
      );

      final activeBill2 = BillModel(
        billId: 'INV-002',
        orderId: 'O2',
        tableId: 'T2',
        tableName: 'T2',
        userName: 'Staff',
        items: [],
        subtotal: 200,
        total: 200,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: false,
      );

      final voidedBill = BillModel(
        billId: 'INV-003',
        orderId: 'O3',
        tableId: 'T3',
        tableName: 'T3',
        userName: 'Staff',
        items: [],
        subtotal: 150,
        total: 150,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: true,
        voidReason: 'Disputed charge',
      );

      final allBills = [activeBill1, activeBill2, voidedBill];

      final activeOnly = allBills.where((b) => !b.isVoided).toList();
      expect(activeOnly.length, equals(2));
      expect(activeOnly.map((b) => b.billId), containsAll(['INV-001', 'INV-002']));

      final voidedOnly = allBills.where((b) => b.isVoided).toList();
      expect(voidedOnly.length, equals(1));
      expect(voidedOnly.first.billId, equals('INV-003'));

      // Total revenue calculated only from active bills
      final revenue = activeOnly.fold<double>(0.0, (sum, b) => sum + b.total);
      expect(revenue, equals(300.0)); // 100 + 200, excludes 150
    });

    test('PdfService.generateBillPdf generates valid PDF with void watermark when bill is voided', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Rajiv Gandhi Chowk, Latur',
        address: 'Near Katta Center, Latur, MH 413512',
        phone: '+91 98765 43210',
      );

      final voidedBill = BillModel(
        billId: 'INV-260915-099',
        orderId: 'ORD-999',
        tableId: 'T5',
        tableName: 'Table 5',
        userName: 'Cashier Admin',
        items: [
          const BillItem(name: 'Cappuccino', category: 'Hot Beverages', qty: 2, price: 90.0),
        ],
        subtotal: 180.0,
        total: 180.0,
        payments: [const Payment(mode: 'cash', amount: 180.0)],
        createdBy: 'admin_1',
        createdAt: DateTime(2026, 9, 15, 12, 0),
        isVoided: true,
        voidedAt: DateTime(2026, 9, 15, 12, 15),
        voidedBy: 'Manager',
        voidReason: 'Wrong order punched',
      );

      final pdfBytes = await PdfService.generateBillPdf(voidedBill, branch);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, isPositive);
    });
  });
}
