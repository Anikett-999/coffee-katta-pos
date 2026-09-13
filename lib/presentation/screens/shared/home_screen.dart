import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../widgets/table_card.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/global/profile_menu.dart';
import '../../providers/active_branch_provider.dart';
import '../admin/admin_main_screen.dart';
import '../../providers/table_provider.dart';
import '../../../services/table_service.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeUserRoleProvider);

    if (activeRole == 'admin') {
      return const AdminMainScreen();
    }

    return const OperationalHomeScreen();
  }
}

class OperationalHomeScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const OperationalHomeScreen({super.key, this.useShell = false});

  @override
  ConsumerState<OperationalHomeScreen> createState() => _OperationalHomeScreenState();
}

class _OperationalHomeScreenState extends ConsumerState<OperationalHomeScreen> {
  String _selectedFilter = 'All';
  String _searchQuery = '';
  late ScrollController _scrollController;
  bool _isAtTop = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset <= 20) {
        if (!_isAtTop) setState(() => _isAtTop = true);
      } else {
        if (_isAtTop) setState(() => _isAtTop = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(tablesStreamProvider);
    final activeRole = ref.watch(activeUserRoleProvider);
    final canCheckout = activeRole == 'admin' || activeRole == 'cashier';
    final branchId = ref.read(activeBranchIdProvider);

    Widget headerControls = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: _isAtTop
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Status Filter Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderWarm, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCoffee.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        style: GoogleFonts.epilogue(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryCoffee,
                        ),
                        icon: const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.primaryCoffee),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        onChanged: (String? newValue) {
                          if (newValue != null) setState(() => _selectedFilter = newValue);
                        },
                        items: ['All', 'Available', 'Occupied', 'Billing']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.epilogue(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textDark,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCoffee.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: GoogleFonts.epilogue(
                          color: AppTheme.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search table...',
                          hintStyle: GoogleFonts.epilogue(
                            color: AppTheme.textDark.withValues(alpha: 0.45),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primaryCoffee),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );

    Widget content = Column(
      children: [
        headerControls,
        // Table Grid
        Expanded(
          child: tablesAsync.when(
            data: (tables) {
              final filteredTables = tables.where((table) {
                final matchesFilter = _selectedFilter == 'All' || 
                                     table.status.toLowerCase() == _selectedFilter.toLowerCase();
                final matchesSearch = table.name.toLowerCase().contains(_searchQuery.toLowerCase());
                return matchesFilter && matchesSearch;
              }).toList();

              if (filteredTables.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant_outlined, size: 64, color: AppTheme.borderWarm),
                      const SizedBox(height: 16),
                      Text(
                        'No tables found',
                        style: GoogleFonts.epilogue(
                          color: AppTheme.textDark.withValues(alpha: 0.45),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredTables.length,
                itemBuilder: (context, index) {
                  final table = filteredTables[index];
                  return TableCard(
                    key: ValueKey(table.tableId),
                    table: table,
                    canCheckout: canCheckout,
                    isAdmin: activeRole == 'admin',
                    onClear: branchId == null
                        ? null
                        : () async {
                            final service = TableService(branchId: branchId);
                            await service.clearTable(table.tableId);
                          },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.maroon)),
            error: (err, stack) => Center(child: Text('❌ Error: $err')),
          ),
        ),
      ],
    );

    if (widget.useShell) {
      return EditorialBackground(useCreamBase: false, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF382012),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      tooltip: 'Menu',
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  if (MediaQuery.of(context).size.width >= 600) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.table_restaurant_rounded, color: AppTheme.warmAmber, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'TABLES',
                            style: GoogleFonts.epilogue(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const ProfileMenu(isDarkHeader: true),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: EditorialBackground(child: content),
    );
  }
}
