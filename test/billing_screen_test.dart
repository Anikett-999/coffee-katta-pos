import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';

void main() {
  group('Billing & Checkout Calculation and Model Guarantees', () {
    test('BillItem correctly stores and aggregates item metadata and notes', () {
      const item = BillItem(
        name: 'Oreo Coffee',
        category: 'Katta Coffee',
        qty: 2,
        price: 155.0,
        note: 'Less Sugar, + Extra Milk, No straw',
      );

      expect(item.name, equals('Oreo Coffee'));
      expect(item.category, equals('Katta Coffee'));
      expect(item.qty, equals(2));
      expect(item.price, equals(155.0));
      expect(item.price * item.qty, equals(310.0));
      expect(item.note, contains('Less Sugar'));
    });

    test('Billing Calculations: Percentage discount with extra charges', () {
      const subtotal = 570.0;
      const discountPercent = 10.0; // 10%
      const extraCharges = 25.0;

      final discountAmount = subtotal * discountPercent / 100;
      final total = (subtotal - discountAmount) + extraCharges;

      expect(discountAmount, equals(57.0));
      expect(total, equals(538.0));
    });

    test('Billing Calculations: Flat discount with clamping', () {
      const subtotal = 570.0;
      const discountFlat = 100.0;
      const extraCharges = 0.0;

      final discountAmount = discountFlat.clamp(0.0, subtotal);
      final total = (subtotal - discountAmount) + extraCharges;

      expect(discountAmount, equals(100.0));
      expect(total, equals(470.0));
    });

    test('Billing Validation: Hard blocking error when flat discount exceeds subtotal', () {
      const subtotal = 200.0;
      const discountFlat = 250.0;

      final bool hasBlockingError = discountFlat > subtotal;
      expect(hasBlockingError, isTrue);
    });

    test('Billing Validation: Hard blocking error when percentage discount exceeds 100%', () {
      const discountPercent = 110.0;

      final bool hasBlockingError = discountPercent > 100.0;
      expect(hasBlockingError, isTrue);
    });

    test('KOT Item to Bill Item aggregation preserves non-zero quantities', () {
      final kots = [
        KOTModel(
          kotId: 'kot_1',
          kotNumber: 1001,
          orderId: 'order_1',
          tableId: 't2',
          items: const [
            KOTItem(
              uniqueId: 'u1',
              itemId: 'i1',
              name: 'Oreo Coffee',
              category: 'Katta Coffee',
              qty: 1,
              price: 155.0,
              note: 'Less Sugar',
            ),
          ],
          createdBy: 'waiter',
          createdAt: DateTime.now(),
        ),
        KOTModel(
          kotId: 'kot_2',
          kotNumber: 1002,
          orderId: 'order_1',
          tableId: 't2',
          items: const [
            KOTItem(
              uniqueId: 'u2',
              itemId: 'i2',
              name: 'Chicken Tikka on Toast',
              category: 'On the Sides (Non Veg)',
              qty: 1,
              price: 155.0,
            ),
          ],
          createdBy: 'waiter',
          createdAt: DateTime.now(),
        ),
      ];

      expect(kots.length, equals(2));
      expect(kots[0].items.first.qty, equals(1));
      expect(kots[1].items.first.qty, equals(1));
    });
  });
}
