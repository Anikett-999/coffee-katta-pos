import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/models/category.dart';
import '../../../../providers/menu_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../category_items_screen.dart';

class CategoryListView extends ConsumerWidget {
  final String searchQuery;

  const CategoryListView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedCategoriesAsync = ref.watch(rankedCategoriesProvider);
    final userAsync = ref.watch(userModelProvider);
    final isAdmin = userAsync.asData?.value?.isAdmin ?? false;

    return rankedCategoriesAsync.when(
      data: (rankedMetrics) {
        final filteredMetrics = rankedMetrics.where((m) => 
          m.category.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

        if (filteredMetrics.isEmpty) {
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
                  child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF8C7B70)),
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty ? 'No categories in menu' : 'No categories match "$searchQuery"',
                  style: const TextStyle(
                    color: Color(0xFF29231F),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tap "+ NEW CATEGORY" above to add your first menu section.',
                  style: TextStyle(color: Color(0xFF6B5E55), fontSize: 13),
                ),
              ],
            ),
          );
        }

        final bool isMobile = MediaQuery.of(context).size.width < 600;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: GridView.builder(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisSpacing: isMobile ? 10 : 14,
                crossAxisSpacing: isMobile ? 10 : 14,
                childAspectRatio: isMobile ? 1.05 : 1.15,
              ),
              itemCount: filteredMetrics.length,
              itemBuilder: (context, index) {
                final metrics = filteredMetrics[index];
                return _CategoryCard(
                  category: metrics.category,
                  isAdmin: isAdmin,
                  totalItems: metrics.totalItems,
                  unavailableItems: metrics.unavailableItems,
                  isMobile: isMobile,
                );
              },
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF382012)),
      ),
      error: (err, stack) => Center(
        child: Text('Error loading categories: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final Category category;
  final bool isAdmin;
  final int totalItems;
  final int unavailableItems;
  final bool isMobile;

  const _CategoryCard({
    required this.category,
    required this.isAdmin,
    required this.totalItems,
    required this.unavailableItems,
    this.isMobile = false,
  });

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('coffee')) return Icons.coffee_rounded;
    if (lower.contains('tea')) return Icons.emoji_food_beverage_rounded;
    if (lower.contains('shake') || lower.contains('freddo')) return Icons.icecream_rounded;
    if (lower.contains('frapp')) return Icons.local_bar_rounded;
    if (lower.contains('non veg') || lower.contains('chicken')) return Icons.restaurant_rounded;
    if (lower.contains('starter') || lower.contains('fries')) return Icons.lunch_dining_rounded;
    if (lower.contains('side') || lower.contains('toast') || lower.contains('bread')) return Icons.bakery_dining_rounded;
    if (lower.contains('beverage') || lower.contains('hot')) return Icons.local_cafe_rounded;
    return Icons.fastfood_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _getCategoryIcon(category.name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(selectedCategoryIdProvider.notifier).state = category.categoryId;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryItemsScreen(category: category),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 11 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Icon Avatar + Category Name + Popup Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isMobile ? 36 : 40,
                    height: isMobile ? 36 : 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF382012).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF382012).withValues(alpha: 0.14)),
                    ),
                    child: Icon(iconData, color: const Color(0xFF382012), size: isMobile ? 19 : 22),
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF29231F),
                        height: 1.15,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin)
                    SizedBox(
                      width: isMobile ? 24 : 28,
                      height: isMobile ? 24 : 28,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert_rounded, size: isMobile ? 18 : 20, color: const Color(0xFF8C7B70)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE8E1D8)),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            CategoryListViewLogic.showCategoryDialog(context, ref, category: category);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, category);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5A3825)),
                                SizedBox(width: 10),
                                Text('Edit Name', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFC0392B)),
                                SizedBox(width: 10),
                                Text('Delete', style: TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              // Operational Metrics Strip (Responsive Wrap prevents right overflow)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  // Total Items Pill
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2.5 : 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F4EF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE8E1D8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: isMobile ? 11 : 12, color: const Color(0xFF5A3825)),
                        const SizedBox(width: 3),
                        Text(
                          '$totalItems ${totalItems == 1 ? 'ITEM' : 'ITEMS'}',
                          style: TextStyle(
                            fontSize: isMobile ? 9.2 : 10.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF5A3825),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Availability Indicator
                  if (totalItems > 0 && unavailableItems > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 7, vertical: isMobile ? 2.5 : 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0ED),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFD5CC)),
                      ),
                      child: Text(
                        '$unavailableItems OUT',
                        style: TextStyle(
                          fontSize: isMobile ? 9.0 : 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFC0392B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    )
                  else if (totalItems > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 7, vertical: isMobile ? 2.5 : 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF7F1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCDE8DA)),
                      ),
                      child: Text(
                        'ALL ACTIVE',
                        style: TextStyle(
                          fontSize: isMobile ? 9.0 : 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF287A55),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 8 : 10),
              // Action Footer Bar
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 5 : 6, horizontal: isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF382012).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MANAGE ITEMS',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF382012),
                        letterSpacing: 0.4,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: isMobile ? 13 : 14, color: const Color(0xFF382012)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B), size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Category?',
              style: TextStyle(color: Color(0xFF29231F), fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}" and all items associated with it?',
          style: const TextStyle(color: Color(0xFF6B5E55), fontSize: 14),
        ),
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
            onPressed: () async {
              try {
                await ref.read(menuControllerProvider).deleteCategory(category.categoryId);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class CategoryListViewLogic {
  static void showCategoryDialog(BuildContext context, WidgetRef ref, {Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              child: const Icon(Icons.category_rounded, color: Color(0xFF382012), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              category == null ? 'New Category' : 'Edit Category',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF29231F),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CATEGORY NAME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5A3825),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              maxLength: 35,
              autofocus: true,
              style: const TextStyle(
                color: Color(0xFF29231F),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Katta Coffee, Starters, Freak Shakes',
                hintStyle: const TextStyle(color: Color(0xFF8C7B70), fontSize: 13.5),
                filled: true,
                fillColor: const Color(0xFFF7F4EF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF382012), width: 1.8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                counterText: "",
              ),
            ),
          ],
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
              final text = nameController.text.trim();
              if (text.isNotEmpty) {
                final newCategory = category?.copyWith(name: text) ?? 
                    Category(
                      categoryId: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: text,
                      order: 999,
                    );
                ref.read(menuControllerProvider).saveCategory(newCategory);
                Navigator.pop(context);
              }
            },
            child: const Text('Save Category', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
