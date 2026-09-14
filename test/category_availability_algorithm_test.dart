import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/category.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/services/menu_availability_service.dart';

void main() {
  group('CategoryAvailabilityAlgorithm Tests', () {
    final catPizza = Category(categoryId: 'cat_pizza', name: 'Pizzas', order: 1);
    final catCoffee = Category(categoryId: 'cat_coffee', name: 'Coffee', order: 2);
    final catBurgers = Category(categoryId: 'cat_burgers', name: 'Burgers', order: 3);
    final catPasta = Category(categoryId: 'cat_pasta', name: 'Pasta', order: 4);
    final catEmpty = Category(categoryId: 'cat_empty', name: 'Specials', order: 5);
    final catAllOut = Category(categoryId: 'cat_all_out', name: 'Seasonal', order: 6);

    test('Ranks categories strictly by availability percentage (not raw counts)', () {
      final items = <Item>[
        // Coffee (2/2 = 100%)
        Item(itemId: 'c1', name: 'Cold Coffee', categoryId: 'cat_coffee', price: 100, isAvailable: true),
        Item(itemId: 'c2', name: 'Hot Coffee', categoryId: 'cat_coffee', price: 80, isAvailable: true),

        // Pizza (9/10 = 90%) - Has more items, but LOWER percentage than coffee!
        for (int i = 1; i <= 9; i++)
          Item(itemId: 'p$i', name: 'Pizza $i', categoryId: 'cat_pizza', price: 200, isAvailable: true),
        Item(itemId: 'p10', name: 'Pizza 10', categoryId: 'cat_pizza', price: 200, isAvailable: false),

        // Burgers (3/5 = 60%)
        Item(itemId: 'b1', name: 'Veg Burger', categoryId: 'cat_burgers', price: 120, isAvailable: true),
        Item(itemId: 'b2', name: 'Cheese Burger', categoryId: 'cat_burgers', price: 140, isAvailable: true),
        Item(itemId: 'b3', name: 'Crispy Burger', categoryId: 'cat_burgers', price: 150, isAvailable: true),
        Item(itemId: 'b4', name: 'BBQ Burger', categoryId: 'cat_burgers', price: 160, isAvailable: false),
        Item(itemId: 'b5', name: 'Double Burger', categoryId: 'cat_burgers', price: 180, isAvailable: false),

        // Pasta (1/4 = 25%)
        Item(itemId: 'pa1', name: 'White Pasta', categoryId: 'cat_pasta', price: 175, isAvailable: true),
        Item(itemId: 'pa2', name: 'Red Pasta', categoryId: 'cat_pasta', price: 175, isAvailable: false),
        Item(itemId: 'pa3', name: 'Pink Pasta', categoryId: 'cat_pasta', price: 185, isAvailable: false),
        Item(itemId: 'pa4', name: 'Pesto Pasta', categoryId: 'cat_pasta', price: 195, isAvailable: false),

        // Seasonal (0/3 = 0%)
        Item(itemId: 's1', name: 'Mango Shake', categoryId: 'cat_all_out', price: 150, isAvailable: false),
        Item(itemId: 's2', name: 'Strawberry Shake', categoryId: 'cat_all_out', price: 150, isAvailable: false),
        Item(itemId: 's3', name: 'Watermelon Cooler', categoryId: 'cat_all_out', price: 120, isAvailable: false),
      ];

      final ranked = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [catPizza, catCoffee, catBurgers, catPasta, catEmpty, catAllOut],
        items: items,
        sortMode: CategorySortMode.availabilityFillRate,
      );

      // Verify ordering:
      // 1. Coffee (100.0%) - even though it only has 2 items vs Pizza's 9 available!
      expect(ranked[0].category.categoryId, 'cat_coffee');
      expect(ranked[0].availabilityPercentage, 100.0);
      expect(ranked[0].availableItems, 2);
      expect(ranked[0].totalItems, 2);

      // 2. Pizza (90.0%)
      expect(ranked[1].category.categoryId, 'cat_pizza');
      expect(ranked[1].availabilityPercentage, 90.0);
      expect(ranked[1].availableItems, 9);
      expect(ranked[1].totalItems, 10);

      // 3. Burgers (60.0%)
      expect(ranked[2].category.categoryId, 'cat_burgers');
      expect(ranked[2].availabilityPercentage, 60.0);

      // 4. Pasta (25.0%)
      expect(ranked[3].category.categoryId, 'cat_pasta');
      expect(ranked[3].availabilityPercentage, 25.0);

      // 5. Seasonal (0.0%, 3 total items)
      expect(ranked[4].category.categoryId, 'cat_all_out');
      expect(ranked[4].availabilityPercentage, 0.0);
      expect(ranked[4].totalItems, 3);

      // 6. Specials (0.0%, 0 items - empty)
      expect(ranked[5].category.categoryId, 'cat_empty');
      expect(ranked[5].availabilityPercentage, 0.0);
      expect(ranked[5].totalItems, 0);
    });

    test('Tie-breaking between categories with identical percentages ranks larger ready catalog first', () {
      final catSmall = Category(categoryId: 'cat_small', name: 'Small Cat', order: 1);
      final catLarge = Category(categoryId: 'cat_large', name: 'Large Cat', order: 2);

      final items = <Item>[
        // Both 100% available:
        // Large has 8/8
        for (int i = 1; i <= 8; i++)
          Item(itemId: 'l$i', name: 'Large $i', categoryId: 'cat_large', price: 100, isAvailable: true),
        // Small has 2/2
        Item(itemId: 'sm1', name: 'Small 1', categoryId: 'cat_small', price: 100, isAvailable: true),
        Item(itemId: 'sm2', name: 'Small 2', categoryId: 'cat_small', price: 100, isAvailable: true),
      ];

      final ranked = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [catSmall, catLarge],
        items: items,
      );

      // catLarge has 8 available vs catSmall with 2 available
      expect(ranked[0].category.categoryId, 'cat_large');
      expect(ranked[1].category.categoryId, 'cat_small');
    });

    test('Exact rational comparison: identical ratios (1/3 vs 2/6) tie-break by available volume', () {
      final catOneThird = Category(categoryId: 'cat_1_3', name: 'A One Third', order: 1);
      final catTwoSixths = Category(categoryId: 'cat_2_6', name: 'B Two Sixths', order: 2);

      final items = <Item>[
        // Cat 1/3
        Item(itemId: 'a1', name: 'Item 1', categoryId: 'cat_1_3', price: 50, isAvailable: true),
        Item(itemId: 'a2', name: 'Item 2', categoryId: 'cat_1_3', price: 50, isAvailable: false),
        Item(itemId: 'a3', name: 'Item 3', categoryId: 'cat_1_3', price: 50, isAvailable: false),

        // Cat 2/6
        Item(itemId: 'b1', name: 'Item 1', categoryId: 'cat_2_6', price: 50, isAvailable: true),
        Item(itemId: 'b2', name: 'Item 2', categoryId: 'cat_2_6', price: 50, isAvailable: true),
        Item(itemId: 'b3', name: 'Item 3', categoryId: 'cat_2_6', price: 50, isAvailable: false),
        Item(itemId: 'b4', name: 'Item 4', categoryId: 'cat_2_6', price: 50, isAvailable: false),
        Item(itemId: 'b5', name: 'Item 5', categoryId: 'cat_2_6', price: 50, isAvailable: false),
        Item(itemId: 'b6', name: 'Item 6', categoryId: 'cat_2_6', price: 50, isAvailable: false),
      ];

      final ranked = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [catOneThird, catTwoSixths],
        items: items,
      );

      // Both are exactly 33.333% fill rate.
      // Tie-breaker 1: available items count -> catTwoSixths (2 available) ranks before catOneThird (1 available)
      expect(ranked[0].category.categoryId, 'cat_2_6');
      expect(ranked[1].category.categoryId, 'cat_1_3');
    });

    test('Edge Cases: empty categories list and empty items list', () {
      // Empty categories
      final emptyResult = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [],
        items: [Item(itemId: '1', name: 'X', categoryId: 'c1', price: 10, isAvailable: true)],
      );
      expect(emptyResult, isEmpty);

      // Empty items (all categories have 0 items)
      final catA = Category(categoryId: 'c_a', name: 'Category A', order: 2);
      final catB = Category(categoryId: 'c_b', name: 'Category B', order: 1);
      final emptyItemsResult = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [catB, catA],
        items: [],
      );
      expect(emptyItemsResult.length, 2);
      expect(emptyItemsResult[0].totalItems, 0);
      expect(emptyItemsResult[0].availableItems, 0);
      expect(emptyItemsResult[0].availabilityPercentage, 0.0);
      // Tie-breaker: alphabetical A before B
      expect(emptyItemsResult[0].category.categoryId, 'c_a');
      expect(emptyItemsResult[1].category.categoryId, 'c_b');
    });

    test('Edge Cases: Orphaned items with unknown categoryId are safely ignored without distortion', () {
      final catValid = Category(categoryId: 'cat_valid', name: 'Valid Cat', order: 1);
      final items = [
        Item(itemId: 'o1', name: 'Orphan 1', categoryId: 'non_existent_1', price: 10, isAvailable: true),
        Item(itemId: 'o2', name: 'Orphan 2', categoryId: 'non_existent_2', price: 10, isAvailable: false),
        Item(itemId: 'v1', name: 'Valid 1', categoryId: 'cat_valid', price: 50, isAvailable: true),
      ];

      final ranked = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [catValid],
        items: items,
      );

      expect(ranked.length, 1);
      expect(ranked[0].category.categoryId, 'cat_valid');
      expect(ranked[0].totalItems, 1);
      expect(ranked[0].availableItems, 1);
      expect(ranked[0].availabilityPercentage, 100.0);
    });

    test('Deterministic total ordering down to unique categoryId when all other metrics tie', () {
      final cat1 = Category(categoryId: 'id_001', name: 'Same Name', order: 1);
      final cat2 = Category(categoryId: 'id_002', name: 'Same Name', order: 1);

      // Identical percentage (100%), identical available (1), identical total (1), identical name ('Same Name')
      final items = [
        Item(itemId: 'i1', name: 'Item 1', categoryId: 'id_001', price: 10, isAvailable: true),
        Item(itemId: 'i2', name: 'Item 2', categoryId: 'id_002', price: 10, isAvailable: true),
      ];

      final rankedForward = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [cat1, cat2],
        items: items,
      );
      final rankedReverse = CategoryAvailabilityAlgorithm.rankCategories(
        categories: [cat2, cat1],
        items: items,
      );

      // Must be 100% deterministic regardless of input permutation:
      expect(rankedForward[0].category.categoryId, 'id_001');
      expect(rankedForward[1].category.categoryId, 'id_002');
      expect(rankedReverse[0].category.categoryId, 'id_001');
      expect(rankedReverse[1].category.categoryId, 'id_002');
    });

    test('Supports alternative sorting modes (Alphabetical and CustomOrder)', () {
      final categories = [
        Category(categoryId: 'c_zeta', name: 'Zeta Category', order: 3),
        Category(categoryId: 'c_alpha', name: 'Alpha Category', order: 1),
        Category(categoryId: 'c_beta', name: 'Beta Category', order: 2),
      ];

      final rankedAlpha = CategoryAvailabilityAlgorithm.rankCategories(
        categories: categories,
        items: [],
        sortMode: CategorySortMode.alphabetical,
      );
      expect(rankedAlpha.map((m) => m.category.name).toList(), ['Alpha Category', 'Beta Category', 'Zeta Category']);

      final rankedOrder = CategoryAvailabilityAlgorithm.rankCategories(
        categories: categories,
        items: [],
        sortMode: CategorySortMode.customOrder,
      );
      expect(rankedOrder.map((m) => m.category.name).toList(), ['Alpha Category', 'Beta Category', 'Zeta Category']);
    });
  });
}
