import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../domain/models/category.dart';
import '../domain/models/item.dart';

class SeedDataService {
  final FirebaseFirestore _firestore;
  final String businessId;
  final String branchId;

  SeedDataService({
    FirebaseFirestore? firestore,
    this.businessId = 'coffee_katta',
    this.branchId = 'latur_main',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> seedMenuData() async {
    try {
      // 1. Read JSON file
      final String jsonString = await rootBundle.loadString('assets/data/menu_items.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      String slugify(String text) {
        return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      }

      // 2. Official categories map
      final Map<String, String> categoryNameToId = {
        'Katta Coffee': 'cat_katta_coffee',
        'Hot Beverages': 'cat_hot_beverages',
        'Freak Shakes': 'cat_freak_shakes',
        'Katta Frappé': 'cat_katta_frappe',
        'Polare Ice Tea': 'cat_polare_ice_tea',
        'Katta Starter': 'cat_katta_starter',
        'On the Sides': 'cat_on_the_sides',
        'Katta Starter (Non Veg)': 'cat_katta_starter_non_veg',
        'On the Sides (Non Veg)': 'cat_on_the_sides_non_veg',
        'Artisan Pizzas': 'cat_artisan_pizzas',
        'Gourmet Burgers': 'cat_gourmet_burgers',
        'Grilled Sandwiches': 'cat_grilled_sandwiches',
        'Italian Pasta': 'cat_italian_pasta',
        'Egg Specialties': 'cat_egg_specialties',
        'Waffle Special Menu': 'cat_waffle_special_menu',
      };

      final List<String> orderedCategories = [
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
      ];

      // Identify any extra categories in JSON
      for (final item in jsonData) {
        final cat = item['category'] as String;
        if (!orderedCategories.contains(cat)) {
          orderedCategories.add(cat);
          categoryNameToId[cat] = 'cat_${slugify(cat)}';
        }
      }

      // 3. Create categories in Firestore
      int catOrder = 1;
      for (final catName in orderedCategories) {
        final categoryId = categoryNameToId[catName] ?? 'cat_${slugify(catName)}';

        final category = Category(
          categoryId: categoryId,
          name: catName,
          order: catOrder++,
        );

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('branches')
            .doc(branchId)
            .collection('menu_categories')
            .doc(categoryId)
            .set(category.toJson());
      }

      // 4. Create items in Firestore
      for (final itemData in jsonData) {
        final catName = itemData['category'] as String;
        final catId = categoryNameToId[catName] ?? 'cat_${slugify(catName)}';
        final itemName = itemData['name'] as String;
        final itemId = 'item_${slugify(itemName)}';

        final item = Item(
          itemId: itemId,
          name: itemName,
          categoryId: catId,
          groupName: itemData['groupName'] ?? '',
          price: (itemData['price'] as num).toDouble(),
          variants: (itemData['variants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          isAvailable: true,
        );

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('branches')
            .doc(branchId)
            .collection('menu_items')
            .doc(itemId)
            .set(item.toJson());
      }

    } catch (e) {
      rethrow;
    }
  }

  Future<void> seedInitialTables() async {
    try {
      for (int i = 1; i <= 20; i++) {
        final tableId = 'T$i';
        String section = 'Indoor AC';
        int capacity = 4;
        if (i >= 9 && i <= 14) {
          section = 'Outdoor Patio';
          capacity = (i >= 13) ? 6 : 4;
        } else if (i >= 15) {
          section = 'Katta High Tops';
          capacity = 2;
        }

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('branches')
            .doc(branchId)
            .collection('tables')
            .doc(tableId)
            .set({
          'tableId': tableId,
          'name': 'Table $i',
          'section': section,
          'capacity': capacity,
          'status': 'available',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}
