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
                Icon(Icons.extension_off_outlined, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 12),
                const Text(
                  'No add-ons created yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create custom add-ons or seed official Coffee Katta presets.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(menuControllerProvider).seedDefaultModifiers(),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Seed Katta Default Add-Ons'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCoffee,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filteredAddons.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final addon = filteredAddons[index];
            return Card(
              elevation: 0,
              color: AppTheme.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderWarm, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCoffee.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_circle_outline, color: AppTheme.primaryCoffee, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                addon.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₹${addon.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: AppTheme.successGreenPrice,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: addon.categoryIds.isEmpty
                                ? [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundWarm,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.borderWarm),
                                      ),
                                      child: const Text('All Categories', style: TextStyle(fontSize: 10, color: AppTheme.textDark)),
                                    )
                                  ]
                                : addon.categoryIds.map((catId) {
                                    final catName = categoryNameMap[catId] ?? catId;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.backgroundWarm,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.borderWarm),
                                      ),
                                      child: Text(
                                        catName,
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textDark),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: addon.isAvailable,
                            activeThumbColor: AppTheme.primaryCoffee,
                            onChanged: (val) {
                              ref.read(menuControllerProvider).toggleAddonAvailability(addon.id, val);
                            },
                          ),
                        ),
                        Text(
                          addon.isAvailable ? 'INSTOCK' : 'OUT',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: addon.isAvailable ? AppTheme.successGreenPrice : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      onSelected: (val) {
                        if (val == 'edit') {
                          AddonDialog.show(context, ref, addon: addon);
                        } else if (val == 'delete') {
                          _confirmDelete(context, ref, addon);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AddOnItem addon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Add-On', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: Text('Are you sure you want to delete "${addon.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(menuControllerProvider).deleteAddon(addon.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
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
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            addon == null ? 'Add New Add-On' : 'Edit Add-On',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Add-On Name',
                      hintText: 'e.g. Extra Espresso Shot, Cheese Dip',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'APPLICABLE CATEGORIES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppTheme.primaryCoffee,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedCategories.isEmpty
                        ? 'Currently applies to ALL categories. Tap below to limit:'
                        : 'Applies to ${selectedCategories.length} selected categories:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allCategories.map((cat) {
                      final isSelected = selectedCategories.contains(cat.categoryId);
                      return FilterChip(
                        label: Text(cat.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textDark)),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryCoffee,
                        backgroundColor: AppTheme.backgroundWarm,
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
                    title: const Text('Available in Stock', style: TextStyle(fontSize: 14, color: AppTheme.textDark)),
                    value: isAvailable,
                    activeThumbColor: AppTheme.primaryCoffee,
                    onChanged: (val) => setState(() => isAvailable = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCoffee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              child: const Text('Save Add-On'),
            ),
          ],
        ),
      ),
    );
  }
}
