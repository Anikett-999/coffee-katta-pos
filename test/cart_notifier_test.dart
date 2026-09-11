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
  });
}

// Helper to access state in tests if state is protected
extension CartNotifierTestExtension on CartNotifier {
  List<CartItem> get debugState => state;
}
