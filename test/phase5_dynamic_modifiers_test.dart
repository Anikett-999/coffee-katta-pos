import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/addon_item.dart';
import 'package:coffee_katta_pos/domain/models/customization_group.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/presentation/screens/waiter/order_screen.dart';

void main() {
  group('Phase 5 - Dynamic Add-Ons and Customization Groups Tests', () {
    test('AddOnItem JSON serialization and deserialization', () {
      final addon = AddOnItem(
        id: 'addon_kitkat',
        name: 'Crushed KitKat',
        price: 25.0,
        categoryIds: const ['cat_thick_shakes', 'cat_cold_coffee'],
        isAvailable: true,
      );

      final json = addon.toJson();
      expect(json['name'], equals('Crushed KitKat'));
      expect(json['price'], equals(25.0));
      expect(json['categoryIds'], equals(['cat_thick_shakes', 'cat_cold_coffee']));
      expect(json['isAvailable'], isTrue);

      final restored = AddOnItem.fromJson(json, id: 'addon_kitkat');
      expect(restored.id, equals('addon_kitkat'));
      expect(restored.name, equals('Crushed KitKat'));
      expect(restored.price, equals(25.0));
      expect(restored.categoryIds.length, equals(2));
      expect(restored.isAvailable, isTrue);

      // Test copyWith
      final updated = addon.copyWith(price: 30.0, isAvailable: false);
      expect(updated.price, equals(30.0));
      expect(updated.isAvailable, isFalse);
      expect(updated.name, equals('Crushed KitKat'));
    });

    test('CustomizationGroup JSON serialization and deserialization', () {
      final group = CustomizationGroup(
        id: 'group_sugar',
        name: 'Sugar Level',
        options: const ['Normal Sugar', 'Less Sugar', 'Sugar Free', 'Extra Sweet'],
        defaultOption: 'Normal Sugar',
        categoryIds: const ['cat_hot_coffee', 'cat_cold_coffee'],
        isAvailable: true,
      );

      final json = group.toJson();
      expect(json['name'], equals('Sugar Level'));
      expect(json['options'].length, equals(4));
      expect(json['defaultOption'], equals('Normal Sugar'));
      expect(json['categoryIds'], equals(['cat_hot_coffee', 'cat_cold_coffee']));
      expect(json['isAvailable'], isTrue);

      final restored = CustomizationGroup.fromJson(json, id: 'group_sugar');
      expect(restored.id, equals('group_sugar'));
      expect(restored.name, equals('Sugar Level'));
      expect(restored.options, contains('Sugar Free'));
      expect(restored.defaultOption, equals('Normal Sugar'));

      // Test copyWith
      final modified = group.copyWith(defaultOption: 'Less Sugar');
      expect(modified.defaultOption, equals('Less Sugar'));
      expect(modified.options.length, equals(4));
    });

    test('Category matching logic for global vs category-specific modifiers', () {
      final globalAddon = AddOnItem(
        id: 'addon_dip',
        name: 'Extra Dip',
        price: 20.0,
        categoryIds: const [], // empty means applies to all categories
      );

      final shakeAddon = AddOnItem(
        id: 'addon_brownie',
        name: 'Brownie Crumbs',
        price: 35.0,
        categoryIds: const ['cat_shakes'],
      );

      // Function matching the logic used in OrderScreen
      bool matchesCategory(List<String> categoryIds, String itemCategoryId) {
        return categoryIds.isEmpty || categoryIds.contains(itemCategoryId);
      }

      expect(matchesCategory(globalAddon.categoryIds, 'cat_shakes'), isTrue);
      expect(matchesCategory(globalAddon.categoryIds, 'cat_hot_coffee'), isTrue);
      expect(matchesCategory(globalAddon.categoryIds, 'cat_pizza'), isTrue);

      expect(matchesCategory(shakeAddon.categoryIds, 'cat_shakes'), isTrue);
      expect(matchesCategory(shakeAddon.categoryIds, 'cat_pizza'), isFalse);
    });

    test('Dynamic Unit Price Calculation with Size Variant and Dynamic Add-Ons', () {
      const basePrice = 110.0; // Cad B Shake
      final variant = ParsedVariant.fromString('Large:30');

      final dynamicAddons = [
        AddOnItem(id: '1', name: 'Extra Choco Chips', price: 20.0),
        AddOnItem(id: '2', name: 'Nutella Drizzle', price: 35.0),
      ];

      final addOnTotal = dynamicAddons.fold<double>(0.0, (sum, a) => sum + a.price);
      final unitPrice = basePrice + variant.extraPrice + addOnTotal;

      expect(unitPrice, equals(195.0));

      // Dynamic Option Group selections
      final Map<String, String> selectedOptions = {
        'Ice Level': 'Less Ice',
        'Sweetness': 'Medium Sweet',
      };

      final List<String> noteParts = [];
      for (final entry in selectedOptions.entries) {
        if (entry.value.isNotEmpty) {
          noteParts.add(entry.value);
        }
      }
      if (dynamicAddons.isNotEmpty) {
        noteParts.add('+ ${dynamicAddons.map((a) => a.name).join(', ')}');
      }

      final fullNote = noteParts.join(', ');
      expect(fullNote, equals('Less Ice, Medium Sweet, + Extra Choco Chips, Nutella Drizzle'));
    });

    test('Dynamic customizer integration into CartItem and KOTItem', () {
      final item = const Item(
        itemId: 'katta_shake_1',
        name: 'Oreo Thick Shake',
        categoryId: 'cat_thick_shakes',
        price: 100,
      );

      final cartItem = CartItem(
        cartId: 'cart_shake_99',
        item: item,
        categoryName: 'Thick Shakes',
        quantity: 3,
        price: 145.0, // 100 base + 20 Large + 25 Crushed KitKat
        variant: 'Large',
        note: 'Less Sweet, + Crushed KitKat',
      );

      expect(cartItem.price, equals(145.0));
      expect(cartItem.quantity, equals(3));
      expect(cartItem.variant, equals('Large'));
      expect(cartItem.note, equals('Less Sweet, + Crushed KitKat'));

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

      expect(kotItem.price, equals(145.0));
      expect(kotItem.qty, equals(3));
      expect(kotItem.variant, equals('Large'));
      expect(kotItem.note, equals('Less Sweet, + Crushed KitKat'));
    });
  });
}
