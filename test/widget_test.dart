import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffee_katta_pos/main.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';
import 'package:coffee_katta_pos/domain/models/category.dart';
import 'package:coffee_katta_pos/presentation/screens/admin/menu/category_items_screen.dart';
import 'package:coffee_katta_pos/presentation/providers/menu_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/auth_provider.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/coffee_katta_brand_badge.dart';

void main() {
  test('AppTheme brand colors smoke test', () {
    expect(AppTheme.espressoBrown.toARGB32(), equals(0xFF5A3825));
    expect(AppTheme.warmCaramel.toARGB32(), equals(0xFFB77945));
    expect(AppTheme.latteCream.toARGB32(), equals(0xFFF7F4EF));
    expect(AppTheme.warmAmber.toARGB32(), equals(0xFFB77945));
    expect(AppTheme.statusAvailable.toARGB32(), equals(0xFF287A55));
    expect(AppTheme.maroon, equals(AppTheme.espressoBrown));
  });

  test('App widget can be instantiated', () {
    const app = CoffeeKattaPOSApp();
    expect(app, isNotNull);
  });

  testWidgets('CategoryItemsScreen renders cleanly without container assertion error', (tester) async {
    const category = Category(categoryId: 'katta_coffee', name: 'Katta Coffee', order: 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedCategoryIdProvider.overrideWith((ref) => 'katta_coffee'),
          itemsByCategoryProvider.overrideWith((ref) => Stream.value([])),
          userModelProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: CategoryItemsScreen(category: category),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Katta Coffee'), findsOneWidget);
    expect(find.byType(CategoryItemsScreen), findsOneWidget);
  });

  testWidgets('CoffeeKattaBrandBadge renders Bearded Man asset and typography', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CoffeeKattaBrandBadge(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coffee Katta'), findsOneWidget);
    expect(find.text('The Beardman Cafe'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
