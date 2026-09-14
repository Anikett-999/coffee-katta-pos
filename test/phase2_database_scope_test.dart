import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';

void main() {
  group('Phase 2 - Multi-Tenant Scoping & Database Isolation', () {
    test('KOTService defaults to coffee_katta business ID and latur_main branch', () {
      final fake = FakeFirebaseFirestore();
      final kotService = KOTService(firestore: fake);
      expect(kotService.businessId, equals('coffee_katta'));
      expect(kotService.branchId, equals('latur_main'));
    });

    test('All service and provider files use coffee_katta and latur_main scopes', () {
      final expectedScopes = {
        'lib/services/billing_service.dart': 'coffee_katta',
        'lib/services/kot_service.dart': 'coffee_katta',
        'lib/services/menu_service.dart': 'coffee_katta',
        'lib/services/table_service.dart': 'coffee_katta',
        'lib/services/seed_data_service.dart': 'coffee_katta',
        'lib/services/branch_service.dart': 'businesses/coffee_katta/branches',
        'lib/services/analytics_service.dart': 'coffee_katta',
        'lib/presentation/providers/branch_provider.dart': 'businesses/coffee_katta/branches',
      };

      for (final entry in expectedScopes.entries) {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'Missing file: ${entry.key}');
        final content = file.readAsStringSync();
        expect(content.contains(entry.value), isTrue,
            reason: '${entry.key} must contain scope "${entry.value}"');
      }
    });

    test('Zero instances of rajmandir_main in lib/ services and providers', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        if (content.contains('rajmandir_main') ||
            content.contains('businesses/rajmandir') ||
            content.contains('shreerajmandir-820c7')) {
          violations.add(file.path);
        }
      }

      expect(violations, isEmpty,
          reason: 'Found legacy Rajmandir database paths in: $violations');
    });

    test('assets/data/menu_items.json contains valid 106 Coffee Katta items across 15 categories', () {
      final menuFile = File('assets/data/menu_items.json');
      expect(menuFile.existsSync(), isTrue);

      final List<dynamic> items = jsonDecode(menuFile.readAsStringSync());
      expect(items.length, equals(106));

      final expectedCategories = {
        'Katta Coffee',
        'Hot Beverages',
        'Freak Shakes',
        'Katta Frappé',
        'Polare Ice Tea',
        'Katta Starter',
        'On the Sides',
        'Katta Starter (Non Veg)',
        'On the Sides (Non Veg)',
        'Artisan Pizzas',
        'Gourmet Burgers',
        'Grilled Sandwiches',
        'Italian Pasta',
        'Egg Specialties',
        'Waffle Special Menu',
      };

      final foundCategories = <String>{};
      for (final item in items) {
        expect(item['name'], isNotNull);
        expect((item['name'] as String).isNotEmpty, isTrue);
        expect(item['price'], isNotNull);
        expect((item['price'] as num) > 0, isTrue);
        expect(item['category'], isNotNull);
        foundCategories.add(item['category'] as String);
      }

      expect(foundCategories, equals(expectedCategories));
    });
  });
}
