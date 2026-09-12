import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';

void main() {
  group('Split Payment Integration & Validation Tests', () {
    test('Split payments correctly sum to total bill amount', () {
      const total = 570.0;
      final splitAmounts = {
        'Cash': 300.0,
        'UPI': 270.0,
        'Card': 0.0,
      };

      final activePayments = splitAmounts.entries
          .where((e) => e.value > 0)
          .map((e) => Payment(mode: e.key.toLowerCase(), amount: e.value))
          .toList();

      final totalAllocated = activePayments.fold(0.0, (sum, p) => sum + p.amount);

      expect(activePayments.length, equals(2));
      expect(totalAllocated, equals(total));
      expect(activePayments[0].mode, equals('cash'));
      expect(activePayments[0].amount, equals(300.0));
      expect(activePayments[1].mode, equals('upi'));
      expect(activePayments[1].amount, equals(270.0));
    });

    test('Split payment validation rejects allocations that do not equal bill total', () {
      const total = 570.0;

      // Under-allocated
      final underAllocated = {'Cash': 200.0, 'UPI': 200.0};
      final underSum = underAllocated.values.fold(0.0, (s, v) => s + v);
      final isUnderValid = (underSum - total).abs() < 0.05;
      expect(isUnderValid, isFalse);
      expect(total - underSum, equals(170.0));

      // Over-allocated
      final overAllocated = {'Cash': 300.0, 'UPI': 300.0};
      final overSum = overAllocated.values.fold(0.0, (s, v) => s + v);
      final isOverValid = (overSum - total).abs() < 0.05;
      expect(isOverValid, isFalse);
      expect(overSum - total, equals(30.0));

      // Exactly allocated (3-way split)
      final exactAllocated = {'Cash': 200.0, 'UPI': 200.0, 'Card': 170.0};
      final exactSum = exactAllocated.values.fold(0.0, (s, v) => s + v);
      final isExactValid = (exactSum - total).abs() < 0.05;
      expect(isExactValid, isTrue);
    });

    test('BillModel preserves multiple payment line items in JSON serialization', () {
      final payments = [
        const Payment(mode: 'cash', amount: 300.0),
        const Payment(mode: 'upi', amount: 270.0),
      ];

      final bill = BillModel(
        billId: 'INV-260912-1001',
        orderId: 'ORD-101',
        tableId: 'table_2',
        tableName: 'Table 2',
        userName: 'Cashier',
        items: const [
          BillItem(name: 'Oreo Coffee', category: 'Katta Coffee', qty: 2, price: 155.0),
          BillItem(name: 'Lemon Ice Tea', category: 'Polare Ice Tea', qty: 1, price: 135.0),
        ],
        subtotal: 445.0,
        discountPercent: 0.0,
        discountAmount: 0.0,
        discountType: 'percent',
        extraCharges: 125.0,
        total: 570.0,
        payments: payments,
        createdBy: 'admin_user',
        createdAt: DateTime.now(),
      );

      final json = bill.toJson();
      expect(json['payments'], isA<List>());
      expect((json['payments'] as List).length, equals(2));

      final restored = BillModel.fromJson(json);
      expect(restored.payments.length, equals(2));
      expect(restored.payments[0].mode, equals('cash'));
      expect(restored.payments[0].amount, equals(300.0));
      expect(restored.payments[1].mode, equals('upi'));
      expect(restored.payments[1].amount, equals(270.0));
    });

    test('Analytics revenue summation accurately splits amounts across payment modes', () {
      final payments = [
        const Payment(mode: 'cash', amount: 350.0),
        const Payment(mode: 'card', amount: 150.0),
      ];

      Map<String, double> aggregatedStats = {'cash': 0.0, 'upi': 0.0, 'card': 0.0};

      for (final p in payments) {
        final mode = p.mode.toLowerCase();
        aggregatedStats[mode] = (aggregatedStats[mode] ?? 0.0) + p.amount;
      }

      expect(aggregatedStats['cash'], equals(350.0));
      expect(aggregatedStats['upi'], equals(0.0));
      expect(aggregatedStats['card'], equals(150.0));
      expect(aggregatedStats.values.fold(0.0, (s, v) => s + v), equals(500.0));
    });
  });
}
