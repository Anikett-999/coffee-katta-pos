import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/domain/models/user_model.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';
import 'package:coffee_katta_pos/presentation/providers/auth_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/printer_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/active_branch_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/table_provider.dart';
import '../../widgets/global/profile_menu.dart';
import '../../widgets/global/editorial_background.dart';
import '../../widgets/global/coffee_katta_brand_badge.dart';

final kotServiceProvider = Provider<KOTService>((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) throw Exception('No active branch selected');
  return KOTService(branchId: branchId);
});

final liveKOTsProvider = StreamProvider<List<KOTModel>>((ref) {
  return ref.watch(kotServiceProvider).watchLiveKOTs();
});

class KOTScreen extends ConsumerStatefulWidget {
  const KOTScreen({super.key});

  @override
  ConsumerState<KOTScreen> createState() => _KOTScreenState();
}

class _KOTScreenState extends ConsumerState<KOTScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'in_prep', 'ready', 'my_tables'
  bool _isFifo = true; // Oldest first (FIFO) is the industry standard for kitchen displays
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveKOTs = ref.watch(liveKOTsProvider);
    final tablesAsync = ref.watch(tablesStreamProvider);
    final currentUser = ref.watch(userModelProvider).value;

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
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        tooltip: 'Menu',
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, color: AppTheme.warmAmber, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'KDS LIVE',
                          style: GoogleFonts.epilogue(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ProfileMenu(isDarkHeader: true),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(
        child: liveKOTs.when(
          data: (allKots) {
            final tables = tablesAsync.value ?? [];

            // Map of active tableId -> activeOrderId for tables that currently have active orders
            final Map<String, String> activeTableOrders = {};
            for (final table in tables) {
              if (table.activeOrderId != null && table.activeOrderId!.isNotEmpty) {
                activeTableOrders[table.tableId] = table.activeOrderId!;
              }
            }

            // Exclude KOTs whose tables have already been cleared or invoiced!
            // When a table is cleared, its activeOrderId becomes null, removing its KOTs from the live KDS
            final activeKots = allKots.where((kot) {
              if (tables.isNotEmpty && kot.tableId.isNotEmpty) {
                final currentActiveOrderId = activeTableOrders[kot.tableId];
                if (currentActiveOrderId == null || currentActiveOrderId != kot.orderId) {
                  return false;
                }
              }
              return true;
            }).toList();

            // 1. Calculate operational metrics for top pulse bar based on active KOTs
            int activeTicketsCount = 0;
            int totalItemsInPrep = 0;
            int overdueTicketsCount = 0;
            int completedTicketsCount = 0;
            int myTablesCount = 0;

            final now = DateTime.now();

            for (final kot in activeKots) {
              final isFullyServed = kot.items.every((i) => i.status == 'served');
              final pendingCount = kot.items.where((i) => i.status != 'served').length;

              if (isFullyServed) {
                completedTicketsCount++;
              } else {
                activeTicketsCount++;
                totalItemsInPrep += pendingCount;
                if (now.difference(kot.createdAt).inMinutes >= 15) {
                  overdueTicketsCount++;
                }
              }

              if (currentUser != null && kot.createdBy == currentUser.userId) {
                myTablesCount++;
              }
            }

            // 2. Filter KOTs based on user selected tabs and search query
            List<KOTModel> filtered = activeKots.where((kot) {
              final isFullyServed = kot.items.every((i) => i.status == 'served');

              // Status Tab Filter
              if (_selectedFilter == 'in_prep' && isFullyServed) {
                return false;
              }
              if (_selectedFilter == 'ready' && !isFullyServed) {
                return false;
              }
              if (_selectedFilter == 'my_tables') {
                if (currentUser == null || kot.createdBy != currentUser.userId) {
                  return false;
                }
              }

              // Search query filter
              if (_searchQuery.isNotEmpty) {
                final tableMatch = kot.tableName.toLowerCase().contains(_searchQuery);
                final kotNumMatch = kot.kotNumber.toString().contains(_searchQuery);
                final waiterMatch = kot.userName.toLowerCase().contains(_searchQuery);
                final itemMatch = kot.items.any((item) => item.name.toLowerCase().contains(_searchQuery));
                return tableMatch || kotNumMatch || waiterMatch || itemMatch;
              }

              return true;
            }).toList();

            // 3. Sort KOTs
            // FIFO (Oldest first) = ascending createdAt
            // Newest first = descending createdAt
            filtered.sort((a, b) {
              if (_isFifo) {
                return a.createdAt.compareTo(b.createdAt);
              } else {
                return b.createdAt.compareTo(a.createdAt);
              }
            });

            return Column(
              children: [
                // --- TOP KITCHEN OPERATIONS PULSE BAR ---
                _buildOperationsPulseBar(
                  activeTicketsCount: activeTicketsCount,
                  totalItemsInPrep: totalItemsInPrep,
                  overdueTicketsCount: overdueTicketsCount,
                  completedTicketsCount: completedTicketsCount,
                ),

                // --- FILTER & CONTROLS TOOLBAR ---
                _buildFilterControlsBar(
                  currentUser: currentUser,
                  allCount: activeKots.length,
                  inPrepCount: activeTicketsCount,
                  readyCount: completedTicketsCount,
                  myCount: myTablesCount,
                ),

                // --- TICKETS GRID / LIST ---
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(activeKots.isEmpty)
                      : _buildResponsiveGrid(filtered, currentUser),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.espressoBrown),
          ),
          error: (e, s) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Failed to load Live KOTs: $e', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- KITCHEN OPERATIONS PULSE BAR ---
  Widget _buildOperationsPulseBar({
    required int activeTicketsCount,
    required int totalItemsInPrep,
    required int overdueTicketsCount,
    required int completedTicketsCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Live Pulse Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.successGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE SYNC',
                    style: GoogleFonts.epilogue(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.successGreen,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Active Tickets Metric
            _buildMetricPill(
              icon: Icons.receipt_long_rounded,
              label: 'Active Tickets',
              value: '$activeTicketsCount',
              color: AppTheme.espressoBrown,
            ),
            const SizedBox(width: 10),

            // Items In Prep Metric
            _buildMetricPill(
              icon: Icons.soup_kitchen_outlined,
              label: 'Items In Prep',
              value: '$totalItemsInPrep',
              color: const Color(0xFFB45309), // Warm amber
            ),
            const SizedBox(width: 10),

            // Overdue Alert Metric
            if (overdueTicketsCount > 0) ...[
              _buildMetricPill(
                icon: Icons.alarm_on_rounded,
                label: 'Overdue (>15m)',
                value: '$overdueTicketsCount',
                color: const Color(0xFFDC2626), // Urgent Red
                isAlert: true,
              ),
              const SizedBox(width: 10),
            ],

            // Completed Tickets Metric
            _buildMetricPill(
              icon: Icons.check_circle_outline_rounded,
              label: 'Ready / Served',
              value: '$completedTicketsCount',
              color: AppTheme.successGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isAlert ? color.withValues(alpha: 0.12) : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isAlert ? 0.45 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.epilogue(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: GoogleFonts.epilogue(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER & CONTROLS TOOLBAR ---
  Widget _buildFilterControlsBar({
    required UserModel? currentUser,
    required int allCount,
    required int inPrepCount,
    required int readyCount,
    required int myCount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 750;

          final filterTabs = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterChip(id: 'all', label: 'All', count: allCount),
              _buildFilterChip(id: 'in_prep', label: 'In Kitchen', count: inPrepCount),
              _buildFilterChip(id: 'ready', label: 'Ready', count: readyCount),
              if (currentUser?.isWaiter == true || currentUser?.isAdmin == true)
                _buildFilterChip(
                  id: 'my_tables',
                  label: currentUser?.isWaiter == true ? 'My Tables' : 'My Orders',
                  count: myCount,
                  icon: Icons.person_pin_circle_outlined,
                ),
            ],
          );

          final searchAndSort = Row(
            mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Search Input
              Expanded(
                flex: isNarrow ? 1 : 0,
                child: SizedBox(
                  width: isNarrow ? null : 220,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search table, KOT #...',
                      hintStyle: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.espressoBrown),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.epilogue(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort Toggle (FIFO vs Newest)
              Tooltip(
                message: _isFifo ? 'Sorted: Oldest First (FIFO Standard)' : 'Sorted: Newest First',
                child: InkWell(
                  onTap: () => setState(() => _isFifo = !_isFifo),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _isFifo ? AppTheme.espressoBrown.withValues(alpha: 0.09) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isFifo ? AppTheme.espressoBrown.withValues(alpha: 0.3) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFifo ? Icons.hourglass_top_rounded : Icons.history_rounded,
                          size: 15,
                          color: _isFifo ? AppTheme.espressoBrown : Colors.black87,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isFifo ? 'FIFO' : 'Newest',
                          style: GoogleFonts.epilogue(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _isFifo ? AppTheme.espressoBrown : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filterTabs,
                const SizedBox(height: 10),
                searchAndSort,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              filterTabs,
              searchAndSort,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    IconData? icon,
  }) {
    final isSelected = _selectedFilter == id;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.espressoBrown : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.espressoBrown : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.espressoBrown.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.black87),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.epilogue(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.epilogue(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RESPONSIVE GRID OF KOT CARDS ---
  Widget _buildResponsiveGrid(List<KOTModel> kots, UserModel? currentUser) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        if (width >= 1550) {
          crossAxisCount = 4;
        } else if (width >= 1150) {
          crossAxisCount = 3;
        } else if (width >= 680) {
          crossAxisCount = 2;
        }

        if (crossAxisCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: kots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _KOTCard(
                key: ValueKey(kots[index].kotId),
                kot: kots[index],
                currentUser: currentUser,
              );
            },
          );
        }

        // Masonry distribution across columns to prevent vertical gaps
        final List<List<KOTModel>> columns = List.generate(crossAxisCount, (_) => []);
        for (int i = 0; i < kots.length; i++) {
          columns[i % crossAxisCount].add(kots[i]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int c = 0; c < crossAxisCount; c++) ...[
                if (c > 0) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final kot in columns[c])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _KOTCard(
                            key: ValueKey(kot.kotId),
                            kot: kot,
                            currentUser: currentUser,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.espressoBrown.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_rounded,
                size: 56,
                color: AppTheme.espressoBrown,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isCompletelyEmpty ? 'Kitchen is Clear' : 'No Tickets Match Filter',
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.espressoBrown,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isCompletelyEmpty
                  ? 'All orders have been prepared and served. Waiting for new KOTs.'
                  : 'Try selecting a different filter tab or clearing your search term.',
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            if (!isCompletelyEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = 'all';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset All Filters'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(140, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  backgroundColor: AppTheme.espressoBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// INDUSTRY-STANDARD KDS CARD COMPONENT
// ==========================================
class _KOTCard extends ConsumerStatefulWidget {
  final KOTModel kot;
  final UserModel? currentUser;

  const _KOTCard({
    super.key,
    required this.kot,
    required this.currentUser,
  });

  @override
  ConsumerState<_KOTCard> createState() => _KOTCardState();
}

class _KOTCardState extends ConsumerState<_KOTCard> {
  late Timer _timer;
  late Duration _elapsed;
  bool _isReprinting = false;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.kot.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.kot.createdAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // 3-Tier KDS Color Thresholds:
  // 🟢 < 8 min: Normal / Fresh
  // 🟠 8 - 15 min: Attention / Medium
  // 🔴 > 15 min: Urgent / Overdue
  Color _getTimerColor() {
    if (_elapsed.inMinutes < 8) {
      return const Color(0xFF287A55); // Green
    }
    if (_elapsed.inMinutes < 15) {
      return const Color(0xFFD97706); // Warm Amber
    }
    return const Color(0xFFDC2626); // Urgent Crimson
  }

  Color _getTimerBgColor() {
    if (_elapsed.inMinutes < 8) {
      return const Color(0xFFE8F5E9);
    }
    if (_elapsed.inMinutes < 15) {
      return const Color(0xFFFEF3C7);
    }
    return const Color(0xFFFEE2E2);
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return "00:00";
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (d.inHours > 0) {
      return "${d.inHours}h ${minutes % 60}m";
    }
    return "${minutes}m ${seconds.toString().padLeft(2, '0')}s";
  }

  // Action: Reprint KOT Ticket via Thermal Printer
  Future<void> _reprintKOT() async {
    if (_isReprinting) return;
    setState(() => _isReprinting = true);

    try {
      final printService = ref.read(printServiceProvider);
      final config = ref.read(printerConfigProvider);
      final bytes = await printService.generateKOTBytes(widget.kot, config.paperSize);
      final success = await printService.printReceipt(bytes, config);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Reprinted KOT #${widget.kot.kotNumber} for ${widget.kot.tableName}'),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.print_disabled_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Printer offline or error. Check printer settings.'),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReprinting = false);
    }
  }

  // Action: Mark All Items in KOT as Served
  Future<void> _serveAllItems() async {
    try {
      await ref.read(kotServiceProvider).markAllItemsServed(kotId: widget.kot.kotId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('All items served for KOT #${widget.kot.kotNumber}'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Action (Admin Only): Deduct Quantity of an Item
  Future<void> _deductItem(KOTItem item) async {
    try {
      await ref.read(kotServiceProvider).deductKotItem(
        kotId: widget.kot.kotId,
        itemUniqueId: item.uniqueId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deduct failed: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Action (Admin Only): Void Item with Confirmation Dialog
  Future<void> _confirmVoidItem(KOTItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text('Void Item?', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to void "${item.name}" from ${widget.kot.tableName}?\nThis will adjust the table total and item count.',
          style: GoogleFonts.epilogue(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.epilogue(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('Void Item', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(kotServiceProvider).removeKotItem(
          kotId: widget.kot.kotId,
          itemUniqueId: item.uniqueId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voided "${item.name}" from KOT #${widget.kot.kotNumber}'),
              backgroundColor: Colors.orange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Void failed: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFullyServed = widget.kot.items.isNotEmpty && widget.kot.items.every((i) => i.status == 'served');
    final servedCount = widget.kot.items.where((i) => i.status == 'served').length;
    final totalCount = widget.kot.items.length;
    final progress = totalCount > 0 ? (servedCount / totalCount) : 0.0;

    final isMyOrder = widget.currentUser != null && widget.kot.createdBy == widget.currentUser!.userId;
    final isAdmin = widget.currentUser?.isAdmin == true;
    final isCashier = widget.currentUser?.isCashier == true;
    final canReprint = isAdmin || isCashier;
    final isOverdue = !isFullyServed && _elapsed.inMinutes >= 15;

    final timeFormatter = DateFormat('h:mm a');
    final formattedTime = timeFormatter.format(widget.kot.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? const Color(0xFFDC2626).withValues(alpha: 0.6)
              : isFullyServed
                  ? AppTheme.successGreen.withValues(alpha: 0.35)
                  : Colors.grey.shade200,
          width: isOverdue ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOverdue
                ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER WITH HIGH CONTRAST & DISTANCE READABILITY ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFullyServed
                    ? [const Color(0xFF1E3A2B), const Color(0xFF152A1F)]
                    : isOverdue
                        ? [const Color(0xFF4A1010), const Color(0xFF380808)]
                        : [const Color(0xFF382012), const Color(0xFF261409)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Table Name & KOT Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.kot.tableName.toUpperCase(),
                              style: GoogleFonts.epilogue(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // KOT Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${widget.kot.kotNumber}',
                              style: GoogleFonts.epilogue(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Waiter info & "YOUR ORDER" badge
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 13, color: Colors.white.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                widget.kot.userName.isEmpty ? 'Server' : widget.kot.userName,
                                style: GoogleFonts.epilogue(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (isMyOrder)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.warmAmber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'YOUR TABLE',
                                style: GoogleFonts.epilogue(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Urgency Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getTimerBgColor(),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getTimerColor().withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverdue
                            ? Icons.alarm_on_rounded
                            : _elapsed.inMinutes < 8
                                ? Icons.timer_outlined
                                : Icons.warning_amber_rounded,
                        size: 14,
                        color: _getTimerColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_elapsed),
                        style: GoogleFonts.epilogue(
                          color: _getTimerColor(),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- PROGRESS BAR ---
          Container(
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFullyServed ? AppTheme.successGreen : AppTheme.espressoBrown,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$servedCount of $totalCount served',
                        style: GoogleFonts.epilogue(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.epilogue(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isFullyServed ? AppTheme.successGreen : AppTheme.espressoBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- ITEMS LIST ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int idx = 0; idx < widget.kot.items.length; idx++) ...[
                  if (idx > 0)
                    Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
                  _buildItemTile(widget.kot.items[idx], isAdmin),
                ],
              ],
            ),
          ),

          // --- FOOTER & CARD ACTIONS ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Placed Time & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '$formattedTime (${_elapsed.inMinutes}m ago)',
                          style: GoogleFonts.epilogue(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (isFullyServed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.successGreen),
                            const SizedBox(width: 4),
                            Text(
                              'READY / SERVED',
                              style: GoogleFonts.epilogue(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Card Action Buttons
                Row(
                  children: [
                    // Reprint Button (Admin / Cashier only)
                    if (canReprint) ...[
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            onPressed: _isReprinting ? null : _reprintKOT,
                            icon: _isReprinting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.print_rounded, size: 14),
                            label: Text(
                              _isReprinting ? 'PRINTING...' : 'REPRINT',
                              style: GoogleFonts.epilogue(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.espressoBrown,
                              side: BorderSide(color: AppTheme.espressoBrown.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Serve All Button (Available to all roles when not all served)
                    if (!isFullyServed) ...[
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: _serveAllItems,
                            icon: const Icon(Icons.done_all_rounded, size: 15),
                            label: Text(
                              'SERVE ALL ITEMS',
                              style: GoogleFonts.epilogue(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ITEM ROW BUILDER ---
  Widget _buildItemTile(KOTItem item, bool isAdmin) {
    final isServed = item.status == 'served';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large High-Contrast Quantity Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isServed
                  ? Colors.grey.shade200
                  : AppTheme.espressoBrown.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isServed
                    ? Colors.grey.shade300
                    : AppTheme.espressoBrown.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '${item.qty}x',
              style: GoogleFonts.epilogue(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isServed ? Colors.grey.shade600 : AppTheme.espressoBrown,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Item Details & Notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: GoogleFonts.epilogue(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          decoration: isServed ? TextDecoration.lineThrough : null,
                          color: isServed ? Colors.grey.shade500 : Colors.black87,
                        ),
                      ),
                    ),
                    if (item.category.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isServed
                              ? Colors.grey.shade100
                              : AppTheme.accentCaramel.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: GoogleFonts.epilogue(
                            color: isServed
                                ? Colors.grey.shade500
                                : AppTheme.accentCaramel,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.variant.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Option: ${item.variant}',
                    style: GoogleFonts.epilogue(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7), // Amber highlight
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.note,
                            style: GoogleFonts.epilogue(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action: Mark Served / Checkmark
          if (isServed)
            InkWell(
              onTap: () {
                // Allow unserving if tapped by mistake
                ref.read(kotServiceProvider).updateItemStatus(
                  kotId: widget.kot.kotId,
                  itemUniqueId: item.uniqueId,
                  status: 'placed',
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.successGreen),
                    const SizedBox(width: 4),
                    Text(
                      'SERVED',
                      style: GoogleFonts.epilogue(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(kotServiceProvider).updateItemStatus(
                    kotId: widget.kot.kotId,
                    itemUniqueId: item.uniqueId,
                    status: 'served',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen.withValues(alpha: 0.12),
                  foregroundColor: AppTheme.successGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: AppTheme.successGreen.withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(
                  'SERVE',
                  style: GoogleFonts.epilogue(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Admin Only: 3-Dot Menu for Void / Deduct
          if (isAdmin) ...[
            const SizedBox(width: 2),
            SizedBox(
              width: 28,
              height: 36,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'deduct') {
                    _deductItem(item);
                  } else if (value == 'void') {
                    _confirmVoidItem(item);
                  }
                },
                itemBuilder: (ctx) => [
                  if (item.qty > 1)
                    PopupMenuItem(
                      value: 'deduct',
                      child: Row(
                        children: [
                          const Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text('Deduct 1 (${item.qty - 1} remaining)', style: GoogleFonts.epilogue(fontSize: 12)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'void',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Void Item', style: GoogleFonts.epilogue(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
