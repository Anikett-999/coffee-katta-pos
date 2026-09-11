import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/presentation/screens/waiter/order_screen.dart';

void main() {
  group('Phase 4 - Waiter Screen Beverage Customizer Tests', () {
    test('ParsedVariant parses various variant string formats correctly', () {
      final v1 = ParsedVariant.fromString('Regular (250ml):0');
      expect(v1.label, equals('Regular (250ml)'));
      expect(v1.extraPrice, equals(0.0));

      final v2 = ParsedVariant.fromString('Large (350ml):30');
      expect(v2.label, equals('Large (350ml)'));
      expect(v2.extraPrice, equals(30.0));

      final v3 = ParsedVariant.fromString('9 inch:80');
      expect(v3.label, equals('9 inch'));
      expect(v3.extraPrice, equals(80.0));

      final vLegacy = ParsedVariant.fromString('Full');
      expect(vLegacy.label, equals('Full'));
      expect(vLegacy.extraPrice, equals(0.0));
    });

    test('Beverage customizer calculations for Cold Coffee with add-ons', () {
      const basePrice = 90.0; // Thick Cold Coffee
      final variant = ParsedVariant.fromString('Large (350ml):30');
      const addOnPrice1 = 30.0; // Extra Ice Cream
      const addOnPrice2 = 30.0; // Extra Espresso Shot

      final unitPrice = basePrice + variant.extraPrice + addOnPrice1 + addOnPrice2;
      expect(unitPrice, equals(180.0));

      // Compose note
      const sugar = 'Less Sugar';
      final addOns = ['Extra Ice Cream', 'Extra Espresso Shot'];
      const customNote = 'No straw';

      final List<String> parts = [sugar];
      if (addOns.isNotEmpty) {
        parts.add('+ ${addOns.join(', ')}');
      }
      if (customNote.isNotEmpty) {
        parts.add(customNote);
      }
      final fullNote = parts.join(', ');

      expect(fullNote, equals('Less Sugar, + Extra Ice Cream, Extra Espresso Shot, No straw'));
    });

    test('CartItem and KOTItem cleanly reflect customized beverage attributes', () {
      final item = const Item(
        itemId: 'item_cold_coffee',
        name: 'Thick Cold Coffee',
        categoryId: 'cat_cold_coffee',
        price: 90,
      );

      final cartItem = CartItem(
        cartId: 'cart_123',
        item: item,
        categoryName: 'Cold Coffee & Shakes',
        quantity: 2,
        price: 150.0,
        variant: 'Large (350ml)',
        note: 'Less Sugar, + Extra Ice Cream',
      );

      expect(cartItem.price, equals(150.0));
      expect(cartItem.variant, equals('Large (350ml)'));
      expect(cartItem.note, equals('Less Sugar, + Extra Ice Cream'));

      // Map to KOTItem
      final kotItem = KOTItem(
        uniqueId: cartItem.cartId,
        itemId: cartItem.item.itemId,
        name: cartItem.item.name,
        category: cartItem.categoryName,
        qty: cartItem.quantity,
        price: cartItem.price,
        variant: cartItem.variant ?? '',
        note: cartItem.note,
      );

      expect(kotItem.price, equals(150.0));
      expect(kotItem.qty, equals(2));
      expect(kotItem.variant, equals('Large (350ml)'));
      expect(kotItem.note, equals('Less Sugar, + Extra Ice Cream'));
    });

    test('Food variant item calculation for Pizza', () {
      const basePrice = 150.0; // Margherita 7 inch
      final v9inch = ParsedVariant.fromString('9 inch:80');

      final unitPrice = basePrice + v9inch.extraPrice;
      expect(unitPrice, equals(230.0));
      expect(v9inch.label, equals('9 inch'));
    });
  });
}
