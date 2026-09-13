import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../widgets/app_drawer.dart';
import 'widgets/category_list_view.dart';
import 'widgets/addon_management_view.dart';
import 'widgets/customization_groups_view.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const MenuManagementScreen({super.key, this.useShell = false});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _searchHint {
    switch (_tabController.index) {
      case 1:
        return 'Search add-ons & modifiers...';
      case 2:
        return 'Search option & choice groups...';
      default:
        return 'Search food & drink categories...';
    }
  }

  String get _actionButtonLabel {
    switch (_tabController.index) {
      case 1:
        return 'NEW ADD-ON';
      case 2:
        return 'NEW OPTION GROUP';
      default:
        return 'NEW CATEGORY';
    }
  }

  void _handleAddAction() {
    switch (_tabController.index) {
      case 1:
        AddonDialog.show(context, ref);
        break;
      case 2:
        CustomizationGroupDialog.show(context, ref);
        break;
      default:
        CategoryListViewLogic.showCategoryDialog(context, ref);
        break;
    }
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
            if (!widget.useShell && Navigator.canPop(context)) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
            ] else if (!widget.useShell) ...[
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
              const SizedBox(width: 4),
            ],
            // Coffee Katta Brand Badge with Bearded Man Logo
            const Expanded(
              child: CoffeeKattaBrandBadge(),
            ),
            // Catalog Badge (Desktop / Tablet only)
            if (MediaQuery.of(context).size.width >= 600) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu_rounded, color: AppTheme.warmAmber, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'MENU CATALOG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Search Box
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F4EF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(
                  color: Color(0xFF29231F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _searchHint,
                  hintStyle: const TextStyle(
                    color: Color(0xFF8C7B70),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF5A3825), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF8C7B70)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Contextual Action Button
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _handleAddAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF287A55), // Forest Green
                foregroundColor: Colors.white,
                elevation: 1,
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: isMobile
                  ? const SizedBox.shrink()
                  : Text(
                      _actionButtonLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E1D8), width: 1.2)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF382012),
        unselectedLabelColor: const Color(0xFF6B5E55),
        indicatorColor: const Color(0xFF382012),
        indicatorWeight: 3.2,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.restaurant_menu_rounded, size: 20),
            text: 'Categories & Items',
          ),
          Tab(
            icon: Icon(Icons.extension_rounded, size: 20),
            text: 'Add-Ons & Pricing',
          ),
          Tab(
            icon: Icon(Icons.tune_rounded, size: 20),
            text: 'Option Groups',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildControlBar(context),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              CategoryListView(searchQuery: _searchQuery),
              AddonManagementView(searchQuery: _searchQuery),
              CustomizationGroupsView(searchQuery: _searchQuery),
            ],
          ),
        ),
      ],
    );

    if (widget.useShell) {
      return EditorialBackground(child: content);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: EditorialBackground(child: content),
          ),
        ],
      ),
    );
  }
}
