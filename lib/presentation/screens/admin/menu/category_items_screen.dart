import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../domain/models/category.dart';
import '../../../../core/app_theme.dart';
import 'widgets/item_list_view.dart';
import '../../../widgets/global/editorial_background.dart';

class CategoryItemsScreen extends ConsumerStatefulWidget {
  final Category category;

  const CategoryItemsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends ConsumerState<CategoryItemsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF382012),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back to Categories',
            ),
            const SizedBox(width: 4),
            // Official Bearded Man Mascot Avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, color: Color(0xFF5A3825), size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title & Subtitle
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'COFFEE KATTA • ITEMS CATALOG',
                    style: TextStyle(
                      color: AppTheme.warmAmber,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Items Catalog Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
              ),
              child: const Text(
                'ITEMS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E1D8), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Search Box
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F0EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search items in ${widget.category.name}...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF8C7B70),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5A3825), size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF8C7B70)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add Item Action Button (Signature Deep Espresso with Warm Amber Accent)
                Container(
                  height: 40,
                  width: isMobile ? 40 : null,
                  decoration: BoxDecoration(
                    color: const Color(0xFF382012),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4E2E1B), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF382012).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2.5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => ItemListViewLogic.showItemDialog(context, ref, widget.category.categoryId),
                      borderRadius: BorderRadius.circular(10),
                      splashColor: AppTheme.warmAmber.withValues(alpha: 0.2),
                      highlightColor: Colors.white10,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 0 : 14),
                        child: isMobile
                            ? const Center(
                                child: Icon(Icons.add_rounded, size: 22, color: AppTheme.warmAmber),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warmAmber.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 14, color: AppTheme.warmAmber),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'ADD ITEM',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildTopHeader(context),
          _buildControlBar(context),
          Expanded(
            child: EditorialBackground(
              child: ItemListView(searchQuery: _searchQuery),
            ),
          ),
        ],
      ),
    );
  }
}
