import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/bill_model.dart';

class BillAggregatedList extends StatelessWidget {
  final List<BillItem> items;
  final String searchQuery;

  const BillAggregatedList({
    super.key,
    required this.items,
    this.searchQuery = '',
  });

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('coffee') || cat.contains('hot')) {
      return Icons.local_cafe_outlined;
    } else if (cat.contains('shake') || cat.contains('frappé') || cat.contains('frappe')) {
      return Icons.blender_outlined;
    } else if (cat.contains('tea') || cat.contains('ice tea')) {
      return Icons.local_drink_outlined;
    } else if (cat.contains('starter') || cat.contains('side') || cat.contains('pizza') || cat.contains('burger')) {
      return Icons.lunch_dining_outlined;
    }
    return Icons.restaurant_menu_outlined;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No items in bill preview',
              style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // Filter items by search query if present
    final query = searchQuery.trim().toLowerCase();
    final displayedItems = query.isEmpty
        ? items
        : items.where((item) {
            return item.name.toLowerCase().contains(query) ||
                item.category.toLowerCase().contains(query) ||
                item.note.toLowerCase().contains(query);
          }).toList();

    if (displayedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 42, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No items matching "$searchQuery"',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Group items by category
    final Map<String, List<BillItem>> groupedItems = {};
    for (var item in displayedItems) {
      final cat = item.category.trim().isEmpty ? 'KATTA SPECIALS' : item.category.trim().toUpperCase();
      groupedItems.putIfAbsent(cat, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groupedItems.entries.map((entry) {
        final categoryName = entry.key;
        final categoryItems = entry.value;
        final categoryIcon = _getCategoryIcon(categoryName);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Low-profile category micro-header bar (as seen in reference image)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F2EB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E1D8), width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(categoryIcon, size: 16, color: AppTheme.primaryCoffee),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppTheme.primaryCoffee,
                        ),
                      ),
                    ),
                    Text(
                      '${categoryItems.length} ${categoryItems.length == 1 ? 'Item' : 'Items'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Item Cards
              ...categoryItems.map((item) => _buildItemCard(item)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard(BillItem item) {
    // Extract potential variant pills or custom notes
    final noteParts = item.note.isNotEmpty ? item.note.split(',').map((s) => s.trim()).toList() : <String>[];
    
    // Check if there are short variant identifiers like "Regular", "Large", "Hot", "Medium", "Cold"
    final variantBadges = <String>[];
    final otherNotes = <String>[];

    for (final part in noteParts) {
      final lower = part.toLowerCase();
      if (lower == 'hot' || lower == 'cold' || lower == 'medium' || lower == 'large' ||
          lower == 'regular' || lower == '7 inch' || lower == '9 inch' || lower == 'cup' ||
          lower.startsWith('size:')) {
        variantBadges.add(part);
      } else {
        otherNotes.add(part);
      }
    }

    final formattedNote = otherNotes.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Thumbnail Placeholder (Future-proof slot for images)
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3EE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E1D8), width: 0.8),
            ),
            child: Icon(
              _getCategoryIcon(item.category),
              size: 26,
              color: AppTheme.primaryCoffee.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 12),

          // Item Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Variant Badges
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    // Variant Pills
                    ...variantBadges.map((v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE8E1D8), width: 0.8),
                          ),
                          child: Text(
                            v,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryCoffee,
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 3),

                // Selected Options / Modifiers / Custom Notes
                if (formattedNote.isNotEmpty) ...[
                  Text(
                    formattedNote,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Subtle Embedded Category Name
                Text(
                  item.category.isNotEmpty ? item.category : 'Katta Specials',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentCaramel,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Column: Read-Only Quantity Pill and Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Read-Only Quantity Pill (No +/- controls)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F3EE),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE8E1D8), width: 0.8),
                    ),
                    child: Text(
                      'Qty ${item.qty}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Final Item Price (Total for this line item)
              Text(
                '₹${(item.price * item.qty).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
