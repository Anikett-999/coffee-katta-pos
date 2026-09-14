import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../../providers/menu_provider.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  int _lastTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _lastTabIndex) {
        if (_lastTabIndex != _tabController.index) {
          _lastTabIndex = _tabController.index;
          _searchController.clear();
          _searchQuery = '';
        }
        if (mounted) setState(() {});
      }
    });

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _getSearchHint({
    int? categoriesCount,
    int? addonsCount,
    int? groupsCount,
  }) {
    switch (_tabController.index) {
      case 1:
        return addonsCount != null ? 'Search $addonsCount add-ons...' : 'Search add-ons & modifiers...';
      case 2:
        return groupsCount != null ? 'Search $groupsCount option groups...' : 'Search option & choice groups...';
      default:
        return categoriesCount != null ? 'Search $categoriesCount categories...' : 'Search food & drink categories...';
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
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
              tooltip: 'Sync Official Menu Catalog',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(menuControllerProvider).seedOfficialMenuCatalog();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Menu catalog synced with 106 official items!'),
                      backgroundColor: Color(0xFF287A55),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error syncing catalog: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs({
    int? categoriesCount,
    int? addonsCount,
    int? groupsCount,
  }) {
    final tabs = [
      (
        icon: Icons.restaurant_menu_rounded,
        label: 'Categories & Items',
        count: categoriesCount,
      ),
      (
        icon: Icons.extension_rounded,
        label: 'Add-Ons & Pricing',
        count: addonsCount,
      ),
      (
        icon: Icons.tune_rounded,
        label: 'Option Groups',
        count: groupsCount,
      ),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2DDD5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _tabController.index == index;

          return GestureDetector(
            onTap: () {
              if (_tabController.index != index) {
                _searchController.clear();
                _searchQuery = '';
                _tabController.animateTo(index);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: isSelected
                    ? Border.all(color: const Color(0xFFE0DAD1), width: 1)
                    : Border.all(color: Colors.transparent, width: 1),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 15.5,
                      color: isSelected
                          ? const Color(0xFF382012)
                          : const Color(0xFF8C7B70),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF29231F)
                            : const Color(0xFF6B5E55),
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (tab.count != null) ...[
                      const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF382012)
                              : const Color(0xFFDFD9CE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${tab.count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF6B5E55),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBox({
    double? width,
    int? categoriesCount,
    int? addonsCount,
    int? groupsCount,
    bool showShortcut = false,
  }) {
    final isFocused = _searchFocusNode.hasFocus;

    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFocused ? const Color(0xFF382012) : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: _getSearchHint(
            categoriesCount: categoriesCount,
            addonsCount: addonsCount,
            groupsCount: groupsCount,
          ),
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
              : (showShortcut && !isFocused && width != null && width >= 250)
                  ? Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5DFD5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ctrl+K',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A6B60),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildActionButton({bool compact = false}) {
    final buttonContent = compact
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
              Text(
                _actionButtonLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    return Container(
      height: 40,
      width: compact ? 40 : null,
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
          onTap: _handleAddAction,
          borderRadius: BorderRadius.circular(10),
          splashColor: AppTheme.warmAmber.withValues(alpha: 0.2),
          highlightColor: Colors.white10,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 14),
            child: buttonContent,
          ),
        ),
      ),
    );
  }

  Widget _buildUpperHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 880;

    final categoriesCount = ref.watch(categoriesStreamProvider).value?.length;
    final addonsCount = ref.watch(addonsStreamProvider).value?.length;
    final groupsCount = ref.watch(customizationGroupsStreamProvider).value?.length;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8E1D8), width: 1.2),
        ),
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
            child: isDesktop
                ? Row(
                    children: [
                      // Left: Modern Segmented Scope Switcher with Live Badges
                      _buildSegmentedTabs(
                        categoriesCount: categoriesCount,
                        addonsCount: addonsCount,
                        groupsCount: groupsCount,
                      ),
                      const Spacer(),
                      // Right: Integrated Search + Action Button
                      _buildSearchBox(
                        width: 270,
                        categoriesCount: categoriesCount,
                        addonsCount: addonsCount,
                        groupsCount: groupsCount,
                        showShortcut: true,
                      ),
                      const SizedBox(width: 10),
                      _buildActionButton(),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Segmented Switcher (scrollable if narrow)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildSegmentedTabs(
                          categoriesCount: categoriesCount,
                          addonsCount: addonsCount,
                          groupsCount: groupsCount,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Row 2: Search + Action Button
                      Row(
                        children: [
                          Expanded(
                            child: _buildSearchBox(
                              categoriesCount: categoriesCount,
                              addonsCount: addonsCount,
                              groupsCount: groupsCount,
                              showShortcut: false,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildActionButton(compact: screenWidth < 480),
                        ],
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
    final content = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          _searchFocusNode.requestFocus();
        },
      },
      child: Column(
        children: [
          _buildUpperHeader(context),
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
      ),
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
