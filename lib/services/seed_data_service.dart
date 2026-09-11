import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../domain/models/category.dart';
import '../domain/models/item.dart';
import 'package:uuid/uuid.dart';

class SeedDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String businessId = 'coffee_katta';
  final String branchId = 'latur_main';

  Future<void> seedMenuData() async {
    try {
      // 1. Read JSON file
      final String jsonString = await rootBundle.loadString('assets/data/menu_items.json');
      final List<dynamic> jsonData = json.decode(jsonString);

      // 2. Identify unique categories
      final Set<String> categoryNames = jsonData.map((item) => item['category'] as String).toSet();
      
      final Map<String, String> categoryNameToId = {};

      // 3. Create categories in Firestore
      int catOrder = 1;
      for (final catName in categoryNames) {
        final categoryId = const Uuid().v4();
        categoryNameToId[catName] = categoryId;

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
        final itemId = const Uuid().v4();
        final catName = itemData['category'] as String;
        final catId = categoryNameToId[catName]!;

        final item = Item(
          itemId: itemId,
          name: itemData['name'],
          categoryId: catId,
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
