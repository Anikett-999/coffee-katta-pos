import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/bill_model.dart';
import 'product_image_placeholder.dart';

/// Redesigned Bill Preview List matching the Coffee Katta reference design.
/// - Embeds category chips inside the item card (no full-width category banners).
/// - Quantity is strictly READ-ONLY (no +/- controls).
/// - Includes ProductImagePlaceholder.
/// - Clean card hierarchy with slightly visible warm borders.
class BillAggregatedList extends StatelessWidget {
  final List<BillItem> items;
  final String searchQuery;

  const BillAggregatedList({
    super.key,
    required this.items,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No items in bill preview',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Active orders will appear here for review',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final query = searchQuery.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? items
        : items.where((i) {
            return i.name.toLowerCase().contains(query) ||
                i.category.toLowerCase().contains(query) ||
                i.note.toLowerCase().contains(query);
          }).toList();

    if (filteredItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No items matching "$searchQuery"',
              style: const TextStyle(fontSize: 14, color: AppTheme.textDark, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildItemCard(context, item);
      },
    );
  }

  Widget _buildItemCard(BuildContext context, BillItem item) {
    final catName = item.category.trim().isEmpty ? 'MENU ITEM' : item.category.trim().toUpperCase();

    // Parse note into configurations and special instructions if applicable
    final List<String> configItems = [];
    String specialInstruction = '';

    if (item.note.isNotEmpty) {
      final parts = item.note.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final part in parts) {
        if (part.toLowerCase().startsWith('no ') ||
            part.toLowerCase().contains('instruction') ||
            part.toLowerCase().contains('parcel') ||
            part.toLowerCase().contains('takeaway') ||
            part.toLowerCase().contains('spicy') ||
            part.toLowerCase().contains('hot')) {
          specialInstruction = specialInstruction.isEmpty ? part : '$specialInstruction • $part';
        } else {
          configItems.add(part.replaceAll('+', '').trim());
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2), // Slightly visible subtle border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Embedded Category Badge (Inside the card at top-left) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF), // Warm cream chip
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE8E1D8), width: 0.8),
            ),
            child: Text(
              catName,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppTheme.primaryCoffee,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Main Content Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Image Placeholder (approx 64x64)
              const ProductImagePlaceholder(size: 64, borderRadius: 10),
              const SizedBox(width: 14),

              // Item Name, Configurations & Special Instructions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Configurations / Modifiers
                    if (configItems.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        configItems.join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Special Instructions
                    if (specialInstruction.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        specialInstruction,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Read-only Quantity Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Text(
                  'Qty ${item.qty}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Item Line Price
              Text(
                '₹${(item.price * item.qty).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(width: 4),

              // Three dots options menu (for note inspection or item details)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Item Details',
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'info',
                    child: Text(
                      'Unit Price: ₹${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (item.note.isNotEmpty)
                    PopupMenuItem(
                      value: 'note',
                      child: Text(
                        'Note: ${item.note}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
