import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../widgets/app_drawer.dart';
import 'widgets/category_list_view.dart';
import 'widgets/addon_management_view.dart';
import 'widgets/customization_groups_view.dart';
import '../../../widgets/global/editorial_background.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const MenuManagementScreen({super.key, this.useShell = false});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    super.dispose();
  }

  String get _searchHint {
    switch (_tabController.index) {
      case 1:
        return 'Search add-ons...';
      case 2:
        return 'Search option groups...';
      default:
        return 'Search categories...';
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

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        // Search Bar & Add Button Section
        Container(
          color: AppTheme.primaryCoffee,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _searchHint,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 15,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 2),
                        child: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.82), size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _handleAddAction,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Navigation Bar
        Container(
          color: AppTheme.cardWhite,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryCoffee,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primaryCoffee,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.restaurant_menu, size: 20), text: 'Categories & Items'),
              Tab(icon: Icon(Icons.add_circle_outline, size: 20), text: 'Add-Ons & Pricing'),
              Tab(icon: Icon(Icons.tune, size: 20), text: 'Option Groups'),
            ],
          ),
        ),

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
      return content;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('MENU MANAGEMENT', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppTheme.primaryCoffee)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        scrolledUnderElevation: 4,
        iconTheme: const IconThemeData(color: AppTheme.primaryCoffee),
      ),
      drawer: widget.useShell ? null : const AppDrawer(),
      body: EditorialBackground(child: content),
    );
  }
}
