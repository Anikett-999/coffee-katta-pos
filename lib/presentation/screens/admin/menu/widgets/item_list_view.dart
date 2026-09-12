import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/models/item.dart';
import '../../../../providers/menu_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../../core/app_theme.dart';

class ItemListView extends ConsumerWidget {
  final String searchQuery;

  const ItemListView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsByCategoryProvider);
    final userAsync = ref.watch(userModelProvider);
    final isAdmin = userAsync.asData?.value?.isAdmin ?? false;
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);

    return itemsAsync.when(
      data: (items) {
        if (selectedCategoryId == null) {
          return const Center(child: Text('Category error. Please go back and re-select.'));
        }

        final filteredItems = items.where((item) {
          return item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                 item.groupName.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE8E1D8)),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF8C7B70)),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'No items in this category yet' : 'No items match "$searchQuery"',
                  style: const TextStyle(color: Color(0xFF29231F), fontSize: 16, fontWeight: FontWeight.w800),
                ),
                if (isAdmin && searchQuery.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF287A55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => ItemListViewLogic.showItemDialog(context, ref, selectedCategoryId),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add First Item', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 112,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _ItemCard(item: item, isAdmin: isAdmin);
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF382012))),
      error: (err, stack) => Center(child: Text('Error loading items: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final Item item;
  final bool isAdmin;

  const _ItemCard({required this.item, required this.isAdmin});

  bool _isNonVeg(Item item) {
    final lower = item.name.toLowerCase();
    final group = item.groupName.toLowerCase();
    return lower.contains('chicken') || lower.contains('meat') || lower.contains('egg') ||
           group.contains('non veg') || group.contains('non-veg');
  }

  Widget _buildDietaryBadge(bool isNonVeg) {
    final color = isNonVeg ? const Color(0xFFC0392B) : const Color(0xFF287A55);
    return Container(
      width: 17,
      height: 17,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: isNonVeg ? BoxShape.rectangle : BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNonVeg = _isNonVeg(item);

    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.65,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isAvailable ? const Color(0xFFE8E1D8) : const Color(0xFFFFD5CC),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Dietary Symbol
            _buildDietaryBadge(isNonVeg),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF29231F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF287A55),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      if (item.variants.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4EF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE8E1D8)),
                          ),
                          child: Text(
                            '${item.variants.length} Sizes',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A3825),
                            ),
                          ),
                        ),
                      ],
                      if (item.groupName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4EF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE8E1D8)),
                          ),
                          child: Text(
                            item.groupName,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF6B5E55), fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Quick 86-ing Switch & Popup Menu
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: item.isAvailable,
                        activeThumbColor: const Color(0xFF287A55),
                        activeTrackColor: const Color(0xFFCDE8DA),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: const Color(0xFFE8E1D8),
                        onChanged: (val) {
                          ref.read(menuControllerProvider).toggleItemAvailability(item.itemId, val);
                        },
                      ),
                    ),
                    Text(
                      item.isAvailable ? 'IN STOCK' : 'OUT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: item.isAvailable ? const Color(0xFF287A55) : const Color(0xFFC0392B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF8C7B70)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE8E1D8)),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEdit(context, ref);
                      } else if (value == 'delete') {
                        _showDelete(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5A3825)),
                            SizedBox(width: 8),
                            Text('Edit Item', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC0392B)),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref) {
    ItemListViewLogic.showItemDialog(context, ref, item.categoryId, item: item);
  }

  void _showDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 24),
            SizedBox(width: 8),
            Text('Delete Item?', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF29231F))),
          ],
        ),
        content: Text('Are you sure you want to delete "${item.name}"?', style: const TextStyle(color: Color(0xFF6B5E55))),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B5E55), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC0392B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              ref.read(menuControllerProvider).deleteItem(item.itemId);
              Navigator.pop(context);
            },
            child: const Text('Delete Item', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class ItemListViewLogic {
  static void showItemDialog(BuildContext context, WidgetRef ref, String categoryId, {Item? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final priceController = TextEditingController(text: item != null ? item.price.toStringAsFixed(0) : '');
    final groupController = TextEditingController(text: item?.groupName ?? '');
    final List<String> variants = List<String>.from(item?.variants ?? []);
    final variantNameController = TextEditingController();
    final variantPriceController = TextEditingController(text: '0');
    bool isAvailable = item?.isAvailable ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF382012).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fastfood_rounded, color: Color(0xFF382012), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                item == null ? 'New Item' : 'Edit Item',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF29231F), fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ITEM NAME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    maxLength: 40,
                    style: const TextStyle(color: Color(0xFF29231F), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Cold Coffee, Peri Peri Fries',
                      hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      counterText: "",
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'BASE PRICE (₹)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Color(0xFF29231F), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(color: Color(0xFF287A55), fontWeight: FontWeight.bold, fontSize: 15),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'GROUP OR TAG (OPTIONAL)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: groupController,
                    style: const TextStyle(color: Color(0xFF29231F), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Special, Seasonal, Non-Veg',
                      hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF7F4EF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Size / Portion Variants
                  const Text(
                    'SIZE / PORTION VARIANTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF5A3825),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional (e.g. Regular +₹0, Large +₹40). Leave empty if standard.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF6B5E55)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: variants.map((v) {
                      final parts = v.split(':');
                      final label = parts[0];
                      final extra = parts.length > 1 ? parts[1] : '0';
                      return Chip(
                        label: Text('$label (+₹$extra)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        backgroundColor: const Color(0xFFF7F4EF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE8E1D8)),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF8C7B70)),
                        onDeleted: () {
                          setState(() => variants.remove(v));
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: variantNameController,
                          style: const TextStyle(color: Color(0xFF29231F), fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Size (e.g. Large)',
                            hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 12.5),
                            filled: true,
                            fillColor: const Color(0xFFF7F4EF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: variantPriceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF29231F), fontSize: 13, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '+₹',
                            prefixText: '+₹',
                            prefixStyle: const TextStyle(color: Color(0xFF287A55), fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: const Color(0xFFF7F4EF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF287A55), size: 28),
                        onPressed: () {
                          final vName = variantNameController.text.trim();
                          final vExtra = double.tryParse(variantPriceController.text.trim()) ?? 0.0;
                          if (vName.isNotEmpty) {
                            setState(() {
                              variants.add('$vName:${vExtra.toStringAsFixed(0)}');
                              variantNameController.clear();
                              variantPriceController.text = '0';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In Stock & Available', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF29231F))),
                    value: isAvailable,
                    activeThumbColor: const Color(0xFF287A55),
                    activeTrackColor: const Color(0xFFCDE8DA),
                    onChanged: (value) => setState(() => isAvailable = value),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B5E55), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF287A55),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  final newItem = item?.copyWith(
                    name: nameController.text.trim(),
                    price: double.tryParse(priceController.text.trim()) ?? 0,
                    groupName: groupController.text.trim(),
                    isAvailable: isAvailable,
                    variants: variants,
                  ) ?? Item(
                    itemId: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    price: double.tryParse(priceController.text.trim()) ?? 0,
                    categoryId: categoryId,
                    groupName: groupController.text.trim(),
                    isAvailable: isAvailable,
                    variants: variants,
                  );
                  ref.read(menuControllerProvider).saveItem(newItem);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save Item', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
