import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';

class MenuEngineeringTab extends StatefulWidget {
  final DailyAnalytics analytics;

  const MenuEngineeringTab({
    super.key,
    required this.analytics,
  });

  @override
  State<MenuEngineeringTab> createState() => _MenuEngineeringTabState();
}

class _MenuEngineeringTabState extends State<MenuEngineeringTab> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  String _sortBy = 'revenue'; // 'revenue' | 'qty' | 'name'

  @override
  Widget build(BuildContext context) {
    final double grossSales = widget.analytics.grossSales > 0
        ? widget.analytics.grossSales
        : widget.analytics.totalSales;

    // Collect all unique categories
    final Set<String> categories = {'ALL'};
    for (var cat in widget.analytics.categoryStats.keys) {
      if (cat.isNotEmpty) categories.add(cat);
    }

    // Filter and sort items
    var items = widget.analytics.itemStats.values.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    if (_sortBy == 'revenue') {
      items.sort((a, b) => b.revenue.compareTo(a.revenue));
    } else if (_sortBy == 'qty') {
      items.sort((a, b) => b.qty.compareTo(a.qty));
    } else if (_sortBy == 'name') {
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Controls Header (Search + Sort)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderWarm, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.epilogue(fontSize: 13, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search menu items...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.espressoBrown),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderWarm),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.borderWarm),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.espressoBrown, width: 1.5),
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundWarm.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundWarm,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderWarm),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.espressoBrown),
                        style: GoogleFonts.epilogue(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.espressoBrown,
                        ),
                        onChanged: (val) {
                          if (val != null) setState(() => _sortBy = val);
                        },
                        items: const [
                          DropdownMenuItem(value: 'revenue', child: Text('Sort by Revenue')),
                          DropdownMenuItem(value: 'qty', child: Text('Sort by Volume (Qty)')),
                          DropdownMenuItem(value: 'name', child: Text('Sort by Name (A-Z)')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Category Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (sel) => setState(() => _selectedCategory = cat),
                        backgroundColor: AppTheme.backgroundWarm,
                        selectedColor: AppTheme.espressoBrown,
                        labelStyle: GoogleFonts.epilogue(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                        side: BorderSide(color: isSelected ? AppTheme.espressoBrown : AppTheme.borderWarm),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Items List or Table
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 40, color: AppTheme.textDark.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Text(
                  'No items found matching your filter',
                  style: GoogleFonts.epilogue(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark.withValues(alpha: 0.5)),
                ),
              ],
            ),
          )
        else if (isDesktop)
          _buildDesktopDataTable(items, grossSales)
        else
          _buildMobileListView(items, grossSales),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopDataTable(List<ItemStat> items, double totalRevenue) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppTheme.backgroundWarm),
          headingTextStyle: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown),
          dataTextStyle: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('RANK')),
            DataColumn(label: Text('ITEM NAME')),
            DataColumn(label: Text('QTY SOLD'), numeric: true),
            DataColumn(label: Text('AVG PRICE'), numeric: true),
            DataColumn(label: Text('TOTAL REVENUE'), numeric: true),
            DataColumn(label: Text('REVENUE SHARE'), numeric: true),
            DataColumn(label: Text('TIER')),
          ],
          rows: items.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            final share = totalRevenue > 0 ? (item.revenue / totalRevenue) * 100 : 0.0;
            final avgPrice = item.qty > 0 ? item.revenue / item.qty : 0.0;
            final isStar = rank <= (items.length * 0.25).clamp(3, 10);

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3 ? AppTheme.accentCaramel.withValues(alpha: 0.15) : AppTheme.backgroundWarm,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.epilogue(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: rank <= 3 ? AppTheme.espressoBrown : AppTheme.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    item.name.toUpperCase(),
                    style: GoogleFonts.epilogue(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text('${item.qty}')),
                DataCell(Text('₹${avgPrice.toStringAsFixed(0)}')),
                DataCell(
                  Text(
                    '₹${item.revenue.toStringAsFixed(0)}',
                    style: GoogleFonts.epilogue(fontWeight: FontWeight.w800, color: AppTheme.espressoBrown),
                  ),
                ),
                DataCell(Text('${share.toStringAsFixed(1)}%')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isStar
                          ? AppTheme.accentCaramel.withValues(alpha: 0.15)
                          : AppTheme.backgroundWarm,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isStar ? AppTheme.accentCaramel : AppTheme.borderWarm,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isStar ? 'STAR SELLER' : 'CORE ITEM',
                      style: GoogleFonts.epilogue(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isStar ? AppTheme.espressoBrown : AppTheme.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileListView(List<ItemStat> items, double totalRevenue) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final rank = index + 1;
        final item = items[index];
        final share = totalRevenue > 0 ? (item.revenue / totalRevenue) * 100 : 0.0;
        final avgPrice = item.qty > 0 ? item.revenue / item.qty : 0.0;
        final isStar = rank <= 3;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderWarm, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isStar ? AppTheme.accentCaramel.withValues(alpha: 0.15) : AppTheme.backgroundWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$rank',
                  style: GoogleFonts.epilogue(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isStar ? AppTheme.espressoBrown : AppTheme.textDark.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.toUpperCase(),
                      style: GoogleFonts.epilogue(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.qty} units • Avg ₹${avgPrice.toStringAsFixed(0)} • ${share.toStringAsFixed(1)}% of sales',
                      style: GoogleFonts.epilogue(
                        fontSize: 10,
                        color: AppTheme.textDark.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${item.revenue.toStringAsFixed(0)}',
                style: GoogleFonts.epilogue(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.espressoBrown,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
