import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/category.dart';
import '../domain/models/item.dart';

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String businessId = 'coffee_katta';
  final String branchId;

  MenuService({required this.branchId});

  CollectionReference get _categoriesCollection => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId)
      .collection('menu_categories');

  CollectionReference get _itemsCollection => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId)
      .collection('menu_items');

  // Watch categories
  Stream<List<Category>> watchCategories() {
    return _categoriesCollection
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Category.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Watch items by category
  Stream<List<Item>> watchItemsByCategory(String categoryId) {
    return _itemsCollection
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // Watch all available items
  Stream<List<Item>> watchAvailableItems() {
    return _itemsCollection
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Item.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  // --- CRUD Operations ---

  // Category CRUD
  Future<void> upsertCategory(Category category) async {
    await _categoriesCollection.doc(category.categoryId).set(category.toJson());
  }

  Future<void> deleteCategory(String categoryId) async {
    // Safety check: Don't delete if there are items in this category
    final items = await _itemsCollection
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();

    if (items.docs.isNotEmpty) {
      throw Exception('Cannot delete category with items. Move or delete items first.');
    }

    await _categoriesCollection.doc(categoryId).delete();
  }

  Future<void> updateCategoryOrder(List<Category> orderedCategories) async {
    final batch = _firestore.batch();
    for (int i = 0; i < orderedCategories.length; i++) {
      batch.update(
        _categoriesCollection.doc(orderedCategories[i].categoryId),
        {'order': i},
      );
    }
    await batch.commit();
  }

  // Item CRUD
  Future<void> upsertItem(Item item) async {
    await _itemsCollection.doc(item.itemId).set(item.toJson());
  }

  Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
  }

  Future<void> updateItemAvailability(String itemId, bool isAvailable) async {
    await _itemsCollection.doc(itemId).update({'isAvailable': isAvailable});
  }
}
