import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/presentation/screens/waiter/order_screen.dart';

void main() {
  group('CartNotifier Unit Tests', () {
    late CartNotifier cartNotifier;
    
    final testItem = Item(
      itemId: 'I1',
      name: 'Paneer Butter Masala',
      categoryId: 'C1',
      price: 250,
      isAvailable: true,
      variants: ['Half', 'Full'],
    );

    final coffeeItem = Item(
      itemId: 'C101',
      name: 'Thick Cold Coffee',
      categoryId: 'cat_cold_coffee',
      price: 90,
      isAvailable: true,
      variants: ['Regular (250ml):0', 'Large (350ml):30'],
    );

    setUp(() {
      cartNotifier = CartNotifier();
    });

    test('addItem adds a new item to cart', () {
      cartNotifier.addItem(testItem, 'Main Course');
      expect(cartNotifier.debugState.length, 1);
      expect(cartNotifier.debugState.first.item.name, 'Paneer Butter Masala');
      expect(cartNotifier.debugState.first.quantity, 1);
    });

    test('addItem increments quantity if same item and variant exists', () {
      cartNotifier.addItem(testItem, 'Main Course', variant: 'Full');
      cartNotifier.addItem(testItem, 'Main Course', variant: 'Full');
      expect(cartNotifier.debugState.length, 1);
      expect(cartNotifier.debugState.first.quantity, 2);
    });

    test('addItem adds distinct items for different variants', () {
      cartNotifier.addItem(testItem, 'Main Course', variant: 'Half');
      cartNotifier.addItem(testItem, 'Main Course', variant: 'Full');
      expect(cartNotifier.debugState.length, 2);
    });

    test('updateQuantity modifies quantity and removes at zero', () {
      cartNotifier.addItem(testItem, 'Main Course');
      final cartId = cartNotifier.debugState.first.cartId;
      
      cartNotifier.updateQuantity(cartId, 1);
      expect(cartNotifier.debugState.first.quantity, 2);
      
      cartNotifier.updateQuantity(cartId, -2);
      expect(cartNotifier.debugState.length, 0);
    });

    test('calculate total correctly', () {
      cartNotifier.addItem(testItem, 'Main Course'); // 250
      cartNotifier.addItem(testItem, 'Main Course'); // 250
      expect(cartNotifier.total, 500);
    });

    test('updateNote sets instructions correctly', () {
       cartNotifier.addItem(testItem, 'Main Course');
       final cartId = cartNotifier.debugState.first.cartId;
       cartNotifier.updateNote(cartId, 'No Spicy');
       expect(cartNotifier.debugState.first.note, 'No Spicy');
    });

    test('addItem with customized variant price updates unit price and calculates total accurately', () {
      // Base price 90, Large +30, Extra Ice Cream +30 -> unit price = 150
      cartNotifier.addItem(
        coffeeItem,
        'Cold Coffee & Shakes',
        variant: 'Large (350ml)',
        price: 150.0,
        note: 'Less Sugar, + Extra Ice Cream',
      );

      expect(cartNotifier.debugState.length, 1);
      final item = cartNotifier.debugState.first;
      expect(item.price, 150.0);
      expect(item.quantity, 1);
      expect(item.variant, 'Large (350ml)');
      expect(item.note, 'Less Sugar, + Extra Ice Cream');
      expect(cartNotifier.total, 150.0);

      // Add another identical one
      cartNotifier.addItem(
        coffeeItem,
        'Cold Coffee & Shakes',
        variant: 'Large (350ml)',
        price: 150.0,
        note: 'Less Sugar, + Extra Ice Cream',
      );
      expect(cartNotifier.debugState.length, 1);
      expect(cartNotifier.debugState.first.quantity, 2);
      expect(cartNotifier.total, 300.0);
    });

    test('addItem with same variant but different notes keeps distinct line items', () {
      // Cup 1: No Sugar
      cartNotifier.addItem(
        coffeeItem,
        'Cold Coffee & Shakes',
        variant: 'Regular (250ml)',
        price: 90.0,
        note: 'No Sugar',
      );

      // Cup 2: Normal Sugar
      cartNotifier.addItem(
        coffeeItem,
        'Cold Coffee & Shakes',
        variant: 'Regular (250ml)',
        price: 90.0,
        note: 'Normal Sugar',
      );

      expect(cartNotifier.debugState.length, 2);
      expect(cartNotifier.debugState[0].note, 'No Sugar');
      expect(cartNotifier.debugState[1].note, 'Normal Sugar');
      expect(cartNotifier.total, 180.0);
    });
  });

  group('Cart Draft Persistence & Resilience Tests', () {
    final testItem = Item(
      itemId: 'I1',
      name: 'Paneer Butter Masala',
      categoryId: 'C1',
      price: 250,
      isAvailable: true,
      variants: ['Half', 'Full'],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CartItem toJson and fromJson round-trip perfectly', () {
      final cartItem = CartItem(
        cartId: 'cart_123',
        item: testItem,
        categoryName: 'Main Course',
        quantity: 3,
        price: 250.0,
        variant: 'Full',
        note: 'Make it spicy',
      );

      final json = cartItem.toJson();
      final restored = CartItem.fromJson(json);

      expect(restored.cartId, 'cart_123');
      expect(restored.item.itemId, 'I1');
      expect(restored.item.name, 'Paneer Butter Masala');
      expect(restored.categoryName, 'Main Course');
      expect(restored.quantity, 3);
      expect(restored.price, 250.0);
      expect(restored.variant, 'Full');
      expect(restored.note, 'Make it spicy');
    });

    test('CartNotifier automatically persists draft to local storage on mutation', () async {
      final notifier = CartNotifier(tableId: 'table_101');
      notifier.addItem(testItem, 'Main Course', variant: 'Full', note: 'Extra spicy');
      await notifier.persistDraft();

      final prefs = await SharedPreferences.getInstance();
      final rawDraft = prefs.getString(CartNotifier.storageKey('table_101'));
      expect(rawDraft, isNotNull);

      final decoded = jsonDecode(rawDraft!) as Map<String, dynamic>;
      expect(decoded.containsKey('items'), isTrue);
      final items = decoded['items'] as List<dynamic>;
      expect(items.length, 1);
      expect(items.first['categoryName'], 'Main Course');
      expect(items.first['quantity'], 1);
      expect(items.first['variant'], 'Full');
      expect(items.first['note'], 'Extra spicy');
    });

    test('New CartNotifier for the same table restores unsent draft', () async {
      // 1. First session: waiter adds items to table_202, then app terminates
      final session1 = CartNotifier(tableId: 'table_202');
      session1.addItem(testItem, 'Main Course', variant: 'Half');
      await session1.persistDraft();

      // 2. Second session: waiter opens table_202 on rebooted terminal
      final session2 = CartNotifier(tableId: 'table_202');
      await session2.loadSavedDraft();

      expect(session2.debugState.length, 1);
      expect(session2.debugState.first.item.name, 'Paneer Butter Masala');
      expect(session2.debugState.first.variant, 'Half');
      expect(session2.isRestoredFromDraft, isTrue);

      // Dismiss notice
      session2.dismissRestoredNotice();
      expect(session2.isRestoredFromDraft, isFalse);
    });

    test('Calling clear() purges draft from storage and resets restoration flag', () async {
      final notifier = CartNotifier(tableId: 'table_303');
      notifier.addItem(testItem, 'Main Course');
      await notifier.persistDraft();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CartNotifier.storageKey('table_303')), isNotNull);

      notifier.clear();
      await notifier.persistDraft();

      expect(notifier.debugState.isEmpty, isTrue);
      expect(notifier.isRestoredFromDraft, isFalse);
      expect(prefs.getString(CartNotifier.storageKey('table_303')), isNull);
    });

    test('Different tables maintain strictly isolated draft carts', () async {
      final table1Notifier = CartNotifier(tableId: 'table_A');
      final table2Notifier = CartNotifier(tableId: 'table_B');

      table1Notifier.addItem(testItem, 'Main Course', variant: 'Half');
      await table1Notifier.persistDraft();

      final coffeeItem = Item(
        itemId: 'C1',
        name: 'Cold Coffee',
        categoryId: 'C2',
        price: 90,
      );
      table2Notifier.addItem(coffeeItem, 'Beverages');
      await table2Notifier.persistDraft();

      // Reopen table_A
      final sessionA = CartNotifier(tableId: 'table_A');
      await sessionA.loadSavedDraft();
      expect(sessionA.debugState.length, 1);
      expect(sessionA.debugState.first.item.name, 'Paneer Butter Masala');

      // Reopen table_B
      final sessionB = CartNotifier(tableId: 'table_B');
      await sessionB.loadSavedDraft();
      expect(sessionB.debugState.length, 1);
      expect(sessionB.debugState.first.item.name, 'Cold Coffee');
    });

    test('Stale drafts (> 24 hours old) are automatically purged on load', () async {
      final prefs = await SharedPreferences.getInstance();
      final staleTimestamp = DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      final staleData = {
        'savedAt': staleTimestamp,
        'items': [
          CartItem(
            cartId: 'stale_1',
            item: testItem,
            categoryName: 'Main Course',
            quantity: 1,
            price: 250,
          ).toJson()
        ],
      };
      await prefs.setString(CartNotifier.storageKey('table_stale'), jsonEncode(staleData));

      final notifier = CartNotifier(tableId: 'table_stale');
      await notifier.loadSavedDraft();

      expect(notifier.debugState.isEmpty, isTrue);
      expect(notifier.isRestoredFromDraft, isFalse);
      expect(prefs.getString(CartNotifier.storageKey('table_stale')), isNull);
    });
  });
}

// Helper to access state in tests if state is protected
extension CartNotifierTestExtension on CartNotifier {
  List<CartItem> get debugState => state;
}
