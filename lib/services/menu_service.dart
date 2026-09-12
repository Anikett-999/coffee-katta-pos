import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/category.dart';
import '../domain/models/item.dart';
import '../domain/models/addon_item.dart';
import '../domain/models/customization_group.dart';

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

  CollectionReference get _addonsCollection => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId)
      .collection('menu_addons');

  CollectionReference get _customizationsCollection => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId)
      .collection('menu_customizations');

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

  // --- Addon Operations ---
  Stream<List<AddOnItem>> watchAddons() {
    return _addonsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AddOnItem.fromJson({...data, 'id': doc.id});
      }).toList();
    });
  }

  Stream<List<AddOnItem>> watchAvailableAddons() {
    return _addonsCollection
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AddOnItem.fromJson({...data, 'id': doc.id});
      }).toList();
    });
  }

  Future<void> upsertAddon(AddOnItem addon) async {
    await _addonsCollection.doc(addon.id).set(addon.toJson());
  }

  Future<void> deleteAddon(String addonId) async {
    await _addonsCollection.doc(addonId).delete();
  }

  Future<void> updateAddonAvailability(String addonId, bool isAvailable) async {
    await _addonsCollection.doc(addonId).update({'isAvailable': isAvailable});
  }

  // --- Customization Group Operations ---
  Stream<List<CustomizationGroup>> watchCustomizationGroups() {
    return _customizationsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CustomizationGroup.fromJson({...data, 'id': doc.id});
      }).toList();
    });
  }

  Stream<List<CustomizationGroup>> watchAvailableCustomizationGroups() {
    return _customizationsCollection
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CustomizationGroup.fromJson({...data, 'id': doc.id});
      }).toList();
    });
  }

  Future<void> upsertCustomizationGroup(CustomizationGroup group) async {
    await _customizationsCollection.doc(group.id).set(group.toJson());
  }

  Future<void> deleteCustomizationGroup(String groupId) async {
    await _customizationsCollection.doc(groupId).delete();
  }

  Future<void> updateCustomizationGroupAvailability(String groupId, bool isAvailable) async {
    await _customizationsCollection.doc(groupId).update({'isAvailable': isAvailable});
  }

  // --- Default Presets Seeding ---
  Future<void> seedDefaultKattaModifiersIfEmpty() async {
    try {
      final addonsSnap = await _addonsCollection.limit(1).get();
      if (addonsSnap.docs.isEmpty) {
        final defaultAddons = [
          // Coffee Add-ons
          const AddOnItem(id: 'addon_extra_shot', name: 'Extra Espresso Shot', price: 30.0, categoryIds: ['cat_katta_coffee', 'cat_hot_beverages']),
          const AddOnItem(id: 'addon_extra_milk', name: 'Extra Milk / Cream', price: 15.0, categoryIds: ['cat_katta_coffee', 'cat_hot_beverages']),
          const AddOnItem(id: 'addon_extra_icecream', name: 'Extra Ice Cream', price: 30.0, categoryIds: ['cat_katta_coffee']),
          const AddOnItem(id: 'addon_whipped_cream', name: 'Whipped Cream', price: 25.0, categoryIds: ['cat_katta_coffee', 'cat_freak_shakes', 'cat_katta_frappe']),
          // Shakes / Frappé / Tea
          const AddOnItem(id: 'addon_icecream_scoop', name: 'Extra Ice Cream Scoop', price: 30.0, categoryIds: ['cat_freak_shakes', 'cat_katta_frappe']),
          const AddOnItem(id: 'addon_choco_drizzle', name: 'Chocolate Drizzle', price: 20.0, categoryIds: ['cat_freak_shakes', 'cat_katta_frappe']),
          // Food / Sides
          const AddOnItem(id: 'addon_cheese_dip', name: 'Extra Cheese Dip', price: 25.0, categoryIds: ['cat_katta_starter', 'cat_on_the_sides', 'cat_katta_starter_non_veg', 'cat_on_the_sides_non_veg']),
          const AddOnItem(id: 'addon_peri_peri', name: 'Peri Peri Seasoning', price: 15.0, categoryIds: ['cat_katta_starter', 'cat_on_the_sides', 'cat_katta_starter_non_veg', 'cat_on_the_sides_non_veg']),
          const AddOnItem(id: 'addon_mayo_dip', name: 'Mayo Dip', price: 15.0, categoryIds: ['cat_katta_starter', 'cat_on_the_sides', 'cat_katta_starter_non_veg', 'cat_on_the_sides_non_veg']),
        ];

        for (final a in defaultAddons) {
          await _addonsCollection.doc(a.id).set(a.toJson());
        }
      }

      final groupsSnap = await _customizationsCollection.limit(1).get();
      if (groupsSnap.docs.isEmpty) {
        final defaultGroups = [
          const CustomizationGroup(
            id: 'group_sugar_level',
            name: 'SUGAR LEVEL',
            options: ['No Sugar', 'Less Sugar', 'Normal Sugar'],
            defaultOption: 'Normal Sugar',
            categoryIds: ['cat_katta_coffee', 'cat_hot_beverages'],
          ),
          const CustomizationGroup(
            id: 'group_ice_level',
            name: 'ICE / CHILL LEVEL',
            options: ['Normal Ice', 'Less Ice', 'Extra Chilled'],
            defaultOption: 'Normal Ice',
            categoryIds: ['cat_freak_shakes', 'cat_katta_frappe', 'cat_polare_ice_tea'],
          ),
          const CustomizationGroup(
            id: 'group_prep_style',
            name: 'PREPARATION STYLE',
            options: ['Normal', 'Extra Crispy', 'Less Spicy'],
            defaultOption: 'Normal',
            categoryIds: ['cat_katta_starter', 'cat_on_the_sides', 'cat_katta_starter_non_veg', 'cat_on_the_sides_non_veg'],
          ),
        ];

        for (final g in defaultGroups) {
          await _customizationsCollection.doc(g.id).set(g.toJson());
        }
      }
    } catch (_) {
      // Non-blocking if offline or rules prevent
    }
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
