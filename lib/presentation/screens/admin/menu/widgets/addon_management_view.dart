import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/addon_item.dart';
import '../../../../../domain/models/category.dart';
import '../../../../providers/menu_provider.dart';

class AddonManagementView extends ConsumerWidget {
  final String searchQuery;

  const AddonManagementView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addonsAsync = ref.watch(addonsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return addonsAsync.when(
      data: (addons) {
        final categories = categoriesAsync.value ?? [];
        final Map<String, String> categoryNameMap = {
          for (final c in categories) c.categoryId: c.name,
        };

        final filteredAddons = addons.where((a) {
          final query = searchQuery.toLowerCase();
          return a.name.toLowerCase().contains(query);
        }).toList();

        if (addons.isEmpty) {
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
                  child: const Icon(Icons.extension_off_rounded, size: 36, color: Color(0xFF8C7B70)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No add-ons created yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF29231F)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create custom add-ons or seed official Coffee Katta presets.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B5E55)),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(menuControllerProvider).seedDefaultModifiers(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Seed Katta Default Add-Ons'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF382012),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }

        if (filteredAddons.isEmpty) {
          return Center(
            child: Text(
              'No add-ons match "$searchQuery"',
              style: const TextStyle(color: Color(0xFF6B5E55), fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        final inStockCount = addons.where((a) => a.isAvailable).length;
        final outOfStockCount = addons.length - inStockCount;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Top Summary Strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE8E1D8)),
                        ),
                        child: Text(
                          'TOTAL: ${addons.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5A3825),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF7F1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCDE8DA)),
                        ),
                        child: Text(
                          '$inStockCount AVAILABLE',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF287A55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (outOfStockCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD5CC)),
                          ),
                          child: Text(
                            '$outOfStockCount OUT OF STOCK',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFC0392B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Add-Ons List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAddons.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final addon = filteredAddons[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Icon Badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF382012).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF382012).withValues(alpha: 0.14)),
                              ),
                              child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF382012), size: 22),
                            ),
                            const SizedBox(width: 14),
                            // Details: Name, Price, and Linked Categories
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addon.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: addon.isAvailable ? const Color(0xFF29231F) : const Color(0xFF8C7B70),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEDF7F1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFCDE8DA)),
                                        ),
                                        child: Text(
                                          '₹${addon.price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF287A55),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: addon.categoryIds.isEmpty
                                        ? [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7F4EF),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFE8E1D8)),
                                              ),
                                              child: const Text(
                                                'All Categories',
                                                style: TextStyle(fontSize: 10.5, color: Color(0xFF5A3825), fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ]
                                        : addon.categoryIds.map((catId) {
                                            final catName = categoryNameMap[catId] ?? catId;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7F4EF),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFE8E1D8)),
                                              ),
                                              child: Text(
                                                catName,
                                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF5A3825), fontWeight: FontWeight.w600),
                                              ),
                                            );
                                          }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            // Stock Status Pill & Switch
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: addon.isAvailable ? const Color(0xFFEDF7F1) : const Color(0xFFFFF0ED),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: addon.isAvailable ? const Color(0xFFCDE8DA) : const Color(0xFFFFD5CC)),
                                  ),
                                  child: Text(
                                    addon.isAvailable ? 'IN STOCK' : 'OUT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: addon.isAvailable ? const Color(0xFF287A55) : const Color(0xFFC0392B),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Switch(
                                  value: addon.isAvailable,
                                  activeThumbColor: const Color(0xFF287A55),
                                  activeTrackColor: const Color(0xFFCDE8DA),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: const Color(0xFFE8E1D8),
                                  onChanged: (val) {
                                    ref.read(menuControllerProvider).toggleAddonAvailability(addon.id, val);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF8C7B70)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFFE8E1D8)),
                                  ),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      AddonDialog.show(context, ref, addon: addon);
                                    } else if (val == 'delete') {
                                      _confirmDelete(context, ref, addon);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5A3825)),
                                          SizedBox(width: 8),
                                          Text('Edit Add-On', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF382012))),
      error: (e, s) => Center(child: Text('Error loading add-ons: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AddOnItem addon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 24),
            SizedBox(width: 8),
            Text('Delete Add-On?', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF29231F))),
          ],
        ),
        content: Text('Are you sure you want to delete "${addon.name}"?', style: const TextStyle(color: Color(0xFF6B5E55))),
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
              ref.read(menuControllerProvider).deleteAddon(addon.id);
              Navigator.pop(context);
            },
            child: const Text('Delete Add-On', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class AddonDialog {
  static void show(BuildContext context, WidgetRef ref, {AddOnItem? addon}) {
    final nameController = TextEditingController(text: addon?.name ?? '');
    final priceController = TextEditingController(text: addon != null ? addon.price.toStringAsFixed(0) : '');
    final categoriesAsync = ref.read(categoriesStreamProvider);
    final List<Category> allCategories = categoriesAsync.value ?? [];
    final Set<String> selectedCategories = Set.from(addon?.categoryIds ?? []);
    bool isAvailable = addon?.isAvailable ?? true;

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
                child: const Icon(Icons.extension_rounded, color: Color(0xFF382012), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                addon == null ? 'New Add-On' : 'Edit Add-On',
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
                    'ADD-ON NAME',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5A3825), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Color(0xFF29231F), fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'e.g. Extra Cheese Dip, Ice Cream Scoop',
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
                  const SizedBox(height: 14),
                  const Text(
                    'PRICE (₹)',
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
                  const SizedBox(height: 16),
                  const Text(
                    'APPLICABLE CATEGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Color(0xFF5A3825),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCategories.isEmpty
                        ? 'Applies to ALL categories by default. Tap to limit:'
                        : 'Limited to ${selectedCategories.length} category:',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B5E55)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allCategories.map((cat) {
                      final isSelected = selectedCategories.contains(cat.categoryId);
                      return FilterChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF29231F),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF382012),
                        backgroundColor: const Color(0xFFF7F4EF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isSelected ? const Color(0xFF382012) : const Color(0xFFE8E1D8)),
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (checked) {
                          setState(() {
                            if (checked) {
                              selectedCategories.add(cat.categoryId);
                            } else {
                              selectedCategories.remove(cat.categoryId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('In Stock & Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF29231F))),
                    value: isAvailable,
                    activeThumbColor: const Color(0xFF287A55),
                    activeTrackColor: const Color(0xFFCDE8DA),
                    onChanged: (val) => setState(() => isAvailable = val),
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
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                if (name.isEmpty) return;

                final newAddon = AddOnItem(
                  id: addon?.id ?? const Uuid().v4(),
                  name: name,
                  price: price,
                  categoryIds: selectedCategories.toList(),
                  isAvailable: isAvailable,
                );

                ref.read(menuControllerProvider).saveAddon(newAddon);
                Navigator.pop(context);
              },
              child: const Text('Save Add-On', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
