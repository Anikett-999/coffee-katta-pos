import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';

void main() {
  group('Phase 6 - Final Billing & Checkout UI Logic Tests', () {
    test('BillItem line item total calculation and read-only attributes', () {
      const item = BillItem(
        name: 'Oreo Coffee',
        category: 'Katta Coffee',
        qty: 2,
        price: 155.0,
        note: 'Less Sugar • Extra Milk',
      );

      final lineTotal = item.price * item.qty;
      expect(lineTotal, equals(310.0));
      expect(item.qty, equals(2));
      expect(item.category, equals('Katta Coffee'));
      expect(item.note, equals('Less Sugar • Extra Milk'));
    });

    test('Billing financial calculations for flat and percentage discounts', () {
      const subtotal = 570.0;
      const extraCharges = 20.0;

      // Scenario 1: 10% discount
      const percentDiscountVal = 10.0;
      final percentDiscountAmount = (subtotal * percentDiscountVal.clamp(0, 100) / 100);
      final percentTotal = (subtotal - percentDiscountAmount) + extraCharges;
      expect(percentDiscountAmount, equals(57.0));
      expect(percentTotal, equals(533.0));

      // Scenario 2: Flat ₹70 discount
      const flatDiscountVal = 70.0;
      final flatDiscountAmount = flatDiscountVal.clamp(0, subtotal);
      final flatTotal = (subtotal - flatDiscountAmount) + extraCharges;
      expect(flatDiscountAmount, equals(70.0));
      expect(flatTotal, equals(520.0));

      // Scenario 3: Flat discount exceeding subtotal (clamped)
      const excessiveDiscount = 600.0;
      final clampedDiscount = excessiveDiscount.clamp(0, subtotal);
      expect(clampedDiscount, equals(subtotal));
    });

    test('Search filter logic correctly filters bill items by name, category, or note', () {
      final items = [
        const BillItem(name: 'Oreo Coffee', category: 'Katta Coffee', qty: 1, price: 155, note: 'Less Sugar'),
        const BillItem(name: 'Chicken Tikka on Toast', category: 'On the Sides', qty: 1, price: 155, note: 'Extra Crispy'),
        const BillItem(name: 'Lemon Ice Tea', category: 'Polare Ice Tea', qty: 1, price: 135, note: 'Normal Ice'),
      ];

      List<BillItem> filterItems(String query) {
        final q = query.trim().toLowerCase();
        if (q.isEmpty) return items;
        return items.where((item) {
          return item.name.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.note.toLowerCase().contains(q);
        }).toList();
      }

      // Filter by name
      expect(filterItems('Oreo').length, equals(1));
      expect(filterItems('Oreo').first.name, equals('Oreo Coffee'));

      // Filter by category
      expect(filterItems('Sides').length, equals(1));
      expect(filterItems('Sides').first.name, equals('Chicken Tikka on Toast'));

      // Filter by note
      expect(filterItems('Crispy').length, equals(1));

      // Empty query returns all
      expect(filterItems('').length, equals(3));
    });

    test('KOTModel status badge reflects isPrinted status correctly', () {
      final printedKot = KOTModel(
        kotId: 'kot_1',
        kotNumber: 1001,
        orderId: 'ord_1',
        tableId: 'tab_2',
        tableName: 'Table 2',
        items: const [],
        isPrinted: true,
        createdBy: 'waiter',
        createdAt: DateTime.now(),
      );

      final pendingKot = KOTModel(
        kotId: 'kot_2',
        kotNumber: 1002,
        orderId: 'ord_1',
        tableId: 'tab_2',
        tableName: 'Table 2',
        items: const [],
        isPrinted: false,
        createdBy: 'waiter',
        createdAt: DateTime.now(),
      );

      expect(printedKot.isPrinted, isTrue);
      expect(pendingKot.isPrinted, isFalse);
    });
  });
}
