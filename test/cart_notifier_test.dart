import 'package:flutter_test/flutter_test.dart';
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
}

// Helper to access state in tests if state is protected
extension CartNotifierTestExtension on CartNotifier {
  List<CartItem> get debugState => state;
}
