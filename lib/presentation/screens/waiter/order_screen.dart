// COFFEE KATTA POS: WAITER ORDERING & BEVERAGE CUSTOMIZER MODULE
// Authorized for Coffee Katta Cafe Workflow & Beverage Customization.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';
import 'package:coffee_katta_pos/domain/models/category.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/domain/models/table_model.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/domain/models/addon_item.dart';
import 'package:coffee_katta_pos/domain/models/customization_group.dart';
import 'package:coffee_katta_pos/services/menu_service.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/presentation/providers/auth_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/printer_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/active_branch_provider.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/profile_menu.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/base_widgets.dart'; // Added for LoadingIndicator
import 'package:coffee_katta_pos/presentation/widgets/global/editorial_background.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/coffee_katta_brand_badge.dart';
import 'package:coffee_katta_pos/services/menu_availability_service.dart';
import 'package:uuid/uuid.dart';

// --- State Providers ---
final menuServiceProvider = Provider((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) throw Exception('No active branch selected');
  return MenuService(branchId: branchId);
});
final kotServiceProvider = Provider((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) throw Exception('No active branch selected');
  return KOTService(branchId: branchId);
});

final categoriesStreamRawProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(menuServiceProvider).watchCategories();
});

// Stream of all items (available + unavailable) for calculating category availability rates
final allCatalogItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(menuServiceProvider).watchAllItems();
});

// Ranks categories by availability fill rate % (mostly filled first, in percentage)
final categoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  final categoriesAsync = ref.watch(categoriesStreamRawProvider);
  final allCatalogItemsAsync = ref.watch(allCatalogItemsProvider);

  if (categoriesAsync.isLoading || allCatalogItemsAsync.isLoading) {
    if (categoriesAsync.hasValue && allCatalogItemsAsync.hasValue) {
      final ranked = CategoryAvailabilityAlgorithm.rankCategories(
        categories: categoriesAsync.value!,
        items: allCatalogItemsAsync.value!,
      );
      return AsyncValue.data(ranked.map((m) => m.category).toList());
    }
    return const AsyncValue.loading();
  }

  if (categoriesAsync.hasError) {
    return AsyncValue.error(categoriesAsync.error!, categoriesAsync.stackTrace!);
  }
  if (allCatalogItemsAsync.hasError) {
    return AsyncValue.error(allCatalogItemsAsync.error!, allCatalogItemsAsync.stackTrace!);
  }

  final categories = categoriesAsync.value ?? [];
  final items = allCatalogItemsAsync.value ?? [];

  final ranked = CategoryAvailabilityAlgorithm.rankCategories(
    categories: categories,
    items: items,
  );

  return AsyncValue.data(ranked.map((m) => m.category).toList());
});

// Load the entire menu into memory so global search is instant (Zero Latency)
final allItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(menuServiceProvider).watchAvailableItems();
});

// Dynamic Add-ons Provider (real-time from Firestore)
final addonsProvider = StreamProvider<List<AddOnItem>>((ref) {
  return ref.watch(menuServiceProvider).watchAvailableAddons();
});

// Dynamic Customization Groups Provider (real-time from Firestore)
final customizationGroupsProvider = StreamProvider<List<CustomizationGroup>>((ref) {
  return ref.watch(menuServiceProvider).watchAvailableCustomizationGroups();
});

// Holds the current Search Text state globally for the UI
final searchQueryProvider = StateProvider<String>((ref) => '');

class ParsedVariant {
  final String label;
  final String raw;
  final double extraPrice;

  const ParsedVariant({
    required this.label,
    required this.raw,
    required this.extraPrice,
  });

  factory ParsedVariant.fromString(String str) {
    if (str.contains(':')) {
      final parts = str.split(':');
      final label = parts[0].trim();
      final extra = double.tryParse(parts[1].trim()) ?? 0.0;
      return ParsedVariant(label: label, raw: str, extraPrice: extra);
    } else {
      return ParsedVariant(label: str.trim(), raw: str, extraPrice: 0.0);
    }
  }
}

class CartItem {
  final String cartId;
  final Item item;
  final String categoryName;
  final int quantity;
  final double price;
  final String? variant;
  final String note;

  CartItem({
    required this.cartId,
    required this.item,
    required this.categoryName,
    required this.quantity,
    double? price,
    this.variant,
    this.note = '',
  }) : price = price ?? item.price;

  CartItem copyWith({int? quantity, double? price, String? note}) {
    return CartItem(
      cartId: cartId,
      item: item,
      categoryName: categoryName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      variant: variant,
      note: note ?? this.note,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(
    Item item,
    String categoryName, {
    String? variant,
    double? price,
    String note = '',
  }) {
    final effectivePrice = price ?? item.price;
    final index = state.indexWhere((i) =>
        i.item.itemId == item.itemId &&
        i.variant == variant &&
        i.note == note &&
        i.price == effectivePrice);

    if (index != -1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) state[i].copyWith(quantity: state[i].quantity + 1) else state[i]
      ];
    } else {
      state = [
        ...state,
        CartItem(
          cartId: const Uuid().v4(),
          item: item,
          categoryName: categoryName,
          quantity: 1,
          price: effectivePrice,
          variant: variant,
          note: note,
        ),
      ];
    }
  }

  void updateQuantity(String cartId, int delta) {
    state = state
        .map((i) {
          if (i.cartId == cartId) {
            final newQty = (i.quantity + delta).clamp(0, 99);
            return i.copyWith(quantity: newQty);
          }
          return i;
        })
        .where((i) => i.quantity > 0)
        .toList();
  }

  void removeItem(String cartId) {
    state = state.where((i) => i.cartId != cartId).toList();
  }

  void updateNote(String cartId, String note) {
    state = [
      for (final i in state)
        if (i.cartId == cartId) i.copyWith(note: note) else i
    ];
  }

  void clear() => state = [];

  double get total => state.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
}

final cartProvider = StateNotifierProvider.family<CartNotifier, List<CartItem>, String>((ref, tableId) => CartNotifier());

// --- Core Screen ---
class OrderScreen extends ConsumerStatefulWidget {
  final TableModel table;
  final int initialIndex;
  const OrderScreen({super.key, required this.table, this.initialIndex = 0});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String? _selectedCategoryId;
  bool _isProcessing = false;
  String _processingStatus = "";
  bool _isUpdatingKotHistory = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Wipe any lingering search state when navigating to a new table
    Future.microtask(() {
      _searchController.clear();
      ref.read(searchQueryProvider.notifier).state = '';
    });
    
    // Auto-open history if requested (e.g. from TableCard "Print Pending" action)
    if (widget.initialIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOrderHistory(context);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sendToKitchen({KOTModel? existingKOT, bool shouldPrint = false}) async {
    final cart = ref.read(cartProvider(widget.table.tableId));
    if (cart.isEmpty && existingKOT == null) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = existingKOT == null ? "Initializing KOT..." : "Preparing Print...";
    });

    final kotService = ref.read(kotServiceProvider);
    final authUser = ref.read(authStateProvider).value;
    String userName = 'Staff';
    if (authUser?.displayName != null && authUser!.displayName!.isNotEmpty) {
      userName = authUser.displayName!;
    } else if (authUser?.email != null) {
      userName = authUser!.email!.split('@')[0];
    }

    final categories = ref.read(categoriesProvider).value ?? [];

    try {
      KOTModel? kot = existingKOT;

      if (kot == null) {
        setState(() => _processingStatus = "Registering order in system...");
        kot = await kotService.createKOT(
          tableId: widget.table.tableId,
          tableName: widget.table.name,
          items: cart.map((i) {
            final matchedCat = categories.where((c) => c.categoryId == i.item.categoryId);
            final catName = matchedCat.isNotEmpty ? matchedCat.first.name : 'General';
            return KOTItem(
                uniqueId: i.cartId,
                itemId: i.item.itemId,
                name: i.item.name,
                category: catName,
                qty: i.quantity,
                price: i.price,
                variant: i.variant ?? '',
                note: i.note);
          }).toList(),
          userId: authUser?.uid ?? 'unknown',
          userName: userName,
        );
      }

      final printService = ref.read(printServiceProvider);
      final config = ref.read(printerConfigProvider);

      bool printSuccess = true;

      if (shouldPrint || existingKOT != null) {
        setState(() => _processingStatus = "Sending to printer...");
        final bytes = await printService.generateKOTBytes(kot, config.paperSize);
        printSuccess = await printService.printReceipt(bytes, config);
        
        if (printSuccess) {
          await kotService.markAsPrinted(kot.kotId, widget.table.tableId);
        }
      }

      if (!printSuccess && mounted) {
        setState(() => _isProcessing = false);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text('Printer Issue'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Saved Successfully! 🟢', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                const SizedBox(height: 12),
                const Text('But printing failed. 🔴', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 16),
                const Text('What would you like to do?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _sendToKitchen(existingKOT: kot);
                },
                child: const Text('RETRY PRINT'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (existingKOT == null) {
                    ref.read(cartProvider(widget.table.tableId).notifier).clear();
                  }
                  Navigator.pop(context); // Exit Order Screen
                },
                child: const Text('FINISH (MANUAL)', style: TextStyle(color: AppTheme.maroon)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (existingKOT == null) {
                    ref.read(cartProvider(widget.table.tableId).notifier).clear();
                  }
                },
                child: const Text('STAY HERE'),
              ),
            ],
          ),
        );
        return;
      }

      if (existingKOT == null) {
        ref.read(cartProvider(widget.table.tableId).notifier).clear();
      }

      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(printSuccess ? '✅ KOT Sent and Printed!' : '✅ KOT Saved Successfully!'),
          backgroundColor: AppTheme.deepGreen,
        ));
        if (existingKOT == null) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _updateKotHistoryItem({
    required KOTModel kot,
    required KOTItem item,
    required bool removeWholeItem,
  }) async {
    if (_isUpdatingKotHistory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(removeWholeItem ? 'Remove Item?' : 'Deduct Item?'),
        content: Text(
          removeWholeItem
              ? 'Remove ${item.name} from KOT #${kot.kotNumber}?'
              : 'Deduct 1 quantity from ${item.name} in KOT #${kot.kotNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: removeWholeItem ? Colors.red.shade700 : AppTheme.maroon,
            ),
            child: Text(removeWholeItem ? 'Remove' : 'Deduct'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdatingKotHistory = true);
    try {
      final kotService = ref.read(kotServiceProvider);
      if (removeWholeItem) {
        await kotService.removeKotItem(kotId: kot.kotId, itemUniqueId: item.uniqueId);
      } else {
        await kotService.deductKotItem(kotId: kot.kotId, itemUniqueId: item.uniqueId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingKotHistory = false);
      }
    }
  }

  void _handleBack(BuildContext context, WidgetRef ref) {
    Navigator.maybePop(context);
  }

  Future<String?> _showUnsentItemsDialog({
    required BuildContext context,
    required int totalItems,
    required double totalAmount,
    required String tableName,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Warm Icon Badge
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.accentCaramel.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppTheme.accentCaramel,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Clear Dialog Title
                const Text(
                  'Unsent Items in Cart',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // 3. Context Ticket Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundWarm,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderWarm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.table_restaurant, size: 18, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 8),
                          Text(
                            'Table $tableName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cardWhite,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderWarm),
                        ),
                        child: Text(
                          '$totalItems ${totalItems == 1 ? "item" : "items"} • ₹${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: AppTheme.successGreenPrice,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Description Text
                const Text(
                  'You have active items on this ticket that haven’t been sent to the kitchen. What would you like to do?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 22),

                // 5. Action Buttons with Clear POS Usability Hierarchy
                // Primary: Keep as Draft & Exit
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'keep'),
                    icon: const Icon(Icons.bookmark_outline, size: 18),
                    label: const Text(
                      'Keep Draft & Exit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCoffee,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Row: Discard (Destructive) & Stay (Neutral)
                Row(
                  children: [
                    // Discard (Soft red tint with red text)
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, 'discard'),
                          icon: const Icon(Icons.delete_outline, size: 17, color: Color(0xFFDC2626)),
                          label: const Text(
                            'Discard',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEF2F2),
                            side: const BorderSide(color: Color(0xFFFECACA)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Stay on Table
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, 'stay'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textDark,
                            side: const BorderSide(color: AppTheme.borderWarm, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'Stay on Table',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
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
    // Determine screen layout boundaries (900px is the crossover point)
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final tableName = widget.table.name.replaceAll('Table ', '');

    final cart = ref.watch(cartProvider(widget.table.tableId));

    return Stack(
      children: [
        PopScope(
          canPop: cart.isEmpty && !_isProcessing,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final totalItems = cart.fold<int>(0, (sum, i) => sum + i.quantity);
            final totalAmount = ref.read(cartProvider(widget.table.tableId).notifier).total;
            final action = await _showUnsentItemsDialog(
              context: context,
              totalItems: totalItems,
              totalAmount: totalAmount,
              tableName: tableName,
            );
            if (!context.mounted) return;
            if (action == 'discard') {
              ref.read(cartProvider(widget.table.tableId).notifier).clear();
              Navigator.of(context).pop();
            } else if (action == 'keep') {
              Navigator.of(context).pop();
            }
          },
          child: EditorialBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(62),
                child: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            onPressed: () => _handleBack(context, ref),
                            tooltip: 'Back',
                          ),
                          const SizedBox(width: 2),
                          CoffeeKattaBrandBadge(showText: MediaQuery.of(context).size.width >= 600),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 1,
                            height: 22,
                            color: Colors.white24,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.table_restaurant_rounded, color: AppTheme.warmAmber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'T-$tableName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: isDesktop ? 260 : (MediaQuery.of(context).size.width > 480 ? 180 : 130),
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF5A3825),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) =>
                                        ref.read(searchQueryProvider.notifier).state = val,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    cursorColor: const Color(0xFF5A3825),
                                    decoration: InputDecoration(
                                      hintText: 'Search...',
                                      hintStyle: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        fontSize: 12,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                if (ref.watch(searchQueryProvider).isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      ref.read(searchQueryProvider.notifier).state = '';
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.close_rounded, size: 16, color: Colors.black54),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                            tooltip: 'View Sent Items',
                            onPressed: () => _showOrderHistory(context),
                          ),
                          const ProfileMenu(isDarkHeader: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildDesktopLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
              bottomNavigationBar: isDesktop ? null : _buildMobileCartBottomBar(),
            ),
          ),
        ),
        if (_isProcessing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: LoadingIndicator(message: _processingStatus),
              ),
            ),
          ),
      ],
    );
  }

  // --- DIETARY TAG IDENTIFIER & BADGES ---
  String _getDietaryType(Item item, String catName) {
    final lower = item.name.toLowerCase();
    final group = item.groupName.toLowerCase();
    final cat = catName.toLowerCase();

    if (lower.contains('egg') || group.contains('egg') || cat.contains('egg')) {
      return 'egg';
    }
    if (lower.contains('chicken') ||
        lower.contains('meat') ||
        lower.contains('non veg') ||
        lower.contains('non-veg') ||
        group.contains('non veg') ||
        group.contains('non-veg') ||
        cat.contains('non veg') ||
        cat.contains('non-veg')) {
      return 'non_veg';
    }
    return 'veg';
  }

  Widget _buildSmallDietaryBadge(String dietaryType) {
    // Vegetarian items will not have any tag as required
    if (dietaryType == 'veg') return const SizedBox.shrink();

    final Color color;
    final bool isSquare;
    if (dietaryType == 'non_veg') {
      color = const Color(0xFFC0392B);
      isSquare = true;
    } else if (dietaryType == 'egg') {
      color = const Color(0xFFE67E22);
      isSquare = false;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: 12,
      height: 12,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // --- COMPONENT: SHARED ITEM GRID ---
  Widget _buildItemGrid(bool isMobile) {
    final query = ref.watch(searchQueryProvider).toLowerCase();
    final allItemsAsync = ref.watch(allItemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return allItemsAsync.when(
      data: (items) {
        // Zero-Latency Filtering Logic natively in memory
        List<Item> displayItems = items;
        
        if (query.isNotEmpty) {
          // Ignore category selections if typing to search everything
          displayItems = items.where((i) => i.name.toLowerCase().contains(query)).toList();
        } else if (_selectedCategoryId != null) {
          displayItems = items.where((i) => i.categoryId == _selectedCategoryId).toList();
        } else {
          displayItems = [];
        }

        if (displayItems.isEmpty) return Center(child: Text(query.isNotEmpty ? 'No items matched "$query"' : 'No items found.'));

        final cart = ref.watch(cartProvider(widget.table.tableId));

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isMobile ? 140 : 160, // Optimized compact sizing for high item visibility
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: isMobile ? 1.05 : 1.2,
          ),
          itemCount: displayItems.length,
          itemBuilder: (context, index) {
            final item = displayItems[index];
            
            // Map category id to real name
            String catName = '';
            if (categoriesAsync.hasValue) {
               final matched = categoriesAsync.value!.where((c) => c.categoryId == item.categoryId);
               if (matched.isNotEmpty) {
                  catName = matched.first.name;
               }
            }

            final inCartCount = cart
                .where((c) => c.item.itemId == item.itemId)
                .fold<int>(0, (sum, c) => sum + c.quantity);

            final dietaryType = _getDietaryType(item, catName);

            return Card(
              elevation: 0,
              color: AppTheme.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: inCartCount > 0
                      ? AppTheme.accentCaramel.withValues(alpha: 0.6)
                      : AppTheme.borderWarm,
                  width: inCartCount > 0 ? 1.5 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  _showItemCustomizer(item, catName);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Section: Item Name, corner dietary flag (non-veg/egg only), and in-cart count badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    height: 1.15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                if (item.variants.length > 1) ...[
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Sizes available',
                                    style: TextStyle(
                                      color: AppTheme.accentCaramel,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (dietaryType != 'veg') ...[
                                _buildSmallDietaryBadge(dietaryType),
                                if (inCartCount > 0) const SizedBox(height: 4),
                              ],
                              if (inCartCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCaramel,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$inCartCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Bottom Section: Price on left, '+' action button on right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.successGreenPrice,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (item.variants.length > 1) {
                                _showItemCustomizer(item, catName);
                              } else {
                                ref
                                    .read(cartProvider(widget.table.tableId).notifier)
                                    .addItem(item, catName);
                                _showItemAddedFeedback('${item.name} added!');
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryCoffee,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryCoffee.withValues(alpha: 0.22),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  void _showItemAddedFeedback(String itemName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName added!'),
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showItemCustomizer(Item item, String catName) {
    final List<ParsedVariant> variants = item.variants
        .map((v) => ParsedVariant.fromString(v))
        .toList();

    ParsedVariant selectedVariant = variants.isNotEmpty
        ? variants.first
        : const ParsedVariant(label: 'Standard', raw: 'Standard:0', extraPrice: 0.0);

    final isCoffee = catName == 'Katta Coffee' ||
        catName == 'Hot Beverages' ||
        item.categoryId == 'cat_katta_coffee' ||
        item.categoryId == 'cat_hot_beverages';

    final isShakeOrTea = catName == 'Freak Shakes' ||
        catName == 'Katta Frappé' ||
        catName == 'Polare Ice Tea' ||
        item.categoryId == 'cat_freak_shakes' ||
        item.categoryId == 'cat_katta_frappe' ||
        item.categoryId == 'cat_polare_ice_tea';

    final dietaryType = _getDietaryType(item, catName);
    final isEgg = dietaryType == 'egg';
    final isNonVeg = dietaryType == 'non_veg';

    // Dynamic Modifiers & Add-ons from Firestore (with zero-latency reactive fallback)
    final dynamicAddons = ref.read(addonsProvider).value ?? [];
    final dynamicGroups = ref.read(customizationGroupsProvider).value ?? [];

    // Filter matching dynamic option groups
    final List<CustomizationGroup> matchingGroups = dynamicGroups.where((g) {
      if (!g.isAvailable) return false;
      if (g.categoryIds.isEmpty) return true;
      return g.categoryIds.contains(item.categoryId);
    }).toList();

    final List<CustomizationGroup> effectiveGroups = matchingGroups.isNotEmpty
        ? matchingGroups
        : [
            CustomizationGroup(
              id: 'fb_style',
              name: isCoffee
                  ? 'SUGAR LEVEL'
                  : (isShakeOrTea ? 'ICE / CHILL LEVEL' : 'PREPARATION STYLE'),
              options: isCoffee
                  ? ['No Sugar', 'Less Sugar', 'Normal Sugar']
                  : (isShakeOrTea
                      ? ['Normal Ice', 'Less Ice', 'Extra Chilled']
                      : ['Normal', 'Extra Crispy', 'Less Spicy']),
              defaultOption: isCoffee
                  ? 'Normal Sugar'
                  : (isShakeOrTea ? 'Normal Ice' : 'Normal'),
            ),
          ];

    // Filter matching dynamic add-ons
    final List<AddOnItem> matchingAddons = dynamicAddons.where((a) {
      if (!a.isAvailable) return false;
      if (a.categoryIds.isEmpty) return true;
      return a.categoryIds.contains(item.categoryId);
    }).toList();

    final List<AddOnItem> effectiveAddons = matchingAddons.isNotEmpty
        ? matchingAddons
        : (isCoffee
            ? [
                const AddOnItem(id: 'fb_shot', name: 'Extra Espresso Shot', price: 30.0),
                const AddOnItem(id: 'fb_milk', name: 'Extra Milk / Cream', price: 15.0),
                const AddOnItem(id: 'fb_icecream', name: 'Extra Ice Cream', price: 30.0),
                const AddOnItem(id: 'fb_whip', name: 'Whipped Cream', price: 25.0),
              ]
            : (isShakeOrTea
                ? [
                    const AddOnItem(id: 'fb_scoop', name: 'Extra Ice Cream Scoop', price: 30.0),
                    const AddOnItem(id: 'fb_whip2', name: 'Whipped Cream', price: 25.0),
                    const AddOnItem(id: 'fb_choco', name: 'Chocolate Drizzle', price: 20.0),
                  ]
                : [
                    const AddOnItem(id: 'fb_cheese', name: 'Extra Cheese Dip', price: 25.0),
                    const AddOnItem(id: 'fb_peri', name: 'Peri Peri Seasoning', price: 15.0),
                    const AddOnItem(id: 'fb_mayo', name: 'Mayo Dip', price: 15.0),
                  ]));

    final Map<String, String> selectedOptions = {
      for (final g in effectiveGroups)
        g.name: g.defaultOption.isNotEmpty
            ? g.defaultOption
            : (g.options.isNotEmpty ? g.options.first : 'Normal'),
    };

    final IconData categoryIcon = isCoffee
        ? Icons.coffee
        : (isShakeOrTea ? Icons.icecream : Icons.restaurant);

    final String hintText = isCoffee
        ? 'e.g. Extra hot, Less milk, Separate cup...'
        : (isShakeOrTea
            ? 'e.g. Extra thick, Less sweet, No straw...'
            : 'e.g. Well toasted, Extra spicy, Pack separate...');

    final Set<String> selectedAddOns = {};
    final TextEditingController specialNoteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          double addOnsTotal = 0.0;
          for (final opt in effectiveAddons) {
            if (selectedAddOns.contains(opt.name)) {
              addOnsTotal += opt.price;
            }
          }
          final double unitPrice = item.price + selectedVariant.extraPrice + addOnsTotal;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.latteCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.espressoBrown.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(categoryIcon, color: AppTheme.espressoBrown, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (dietaryType != 'veg')
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildSmallDietaryBadge(dietaryType),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.espressoBrown,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  catName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isNonVeg
                                      ? '• Non-Veg'
                                      : (isEgg ? '• Contains Egg' : '• Veg'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isNonVeg
                                        ? Colors.red[700]
                                        : (isEgg ? const Color(0xFFE67E22) : Colors.green[800]),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 1. Size / Variant Selection (if multiple variants exist)
                  if (variants.length > 1) ...[
                    const Text(
                      'SIZE / VARIANT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.warmCaramel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: variants.map((v) {
                        final isSelected = selectedVariant.label == v.label;
                        return ChoiceChip(
                          label: Text(
                            v.extraPrice > 0
                                ? '${v.label} (+₹${v.extraPrice.toStringAsFixed(0)})'
                                : v.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.espressoBrown,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.espressoBrown,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedVariant = v);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Dynamic Option Groups (Sugar, Ice, Prep Style, etc.)
                  for (final group in effectiveGroups) ...[
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.options.map((opt) {
                        final isSelected = selectedOptions[group.name] == opt;
                        return ChoiceChip(
                          label: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : AppTheme.espressoBrown,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.warmCaramel,
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedOptions[group.name] = opt);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Dynamic Optional Add-ons & Pricing
                  if (effectiveAddons.isNotEmpty) ...[
                    const Text(
                      'OPTIONAL ADD-ONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: effectiveAddons.map((opt) {
                        final isChecked = selectedAddOns.contains(opt.name);
                        return FilterChip(
                          label: Text(
                            '+ ${opt.name} (₹${opt.price.toStringAsFixed(0)})',
                            style: TextStyle(
                              color: isChecked ? Colors.white : AppTheme.espressoBrown,
                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isChecked,
                          selectedColor: AppTheme.warmAmber,
                          backgroundColor: Colors.white,
                          checkmarkColor: Colors.white,
                          onSelected: (checked) {
                            setModalState(() {
                              if (checked) {
                                selectedAddOns.add(opt.name);
                              } else {
                                selectedAddOns.remove(opt.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. Special Instructions TextField
                  const Text(
                    'SPECIAL INSTRUCTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppTheme.primaryCoffee,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: specialNoteController,
                    style: const TextStyle(
                      color: AppTheme.textDark, // High-contrast, crisp readable text #29231F
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppTheme.primaryCoffee,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: AppTheme.textDark.withValues(alpha: 0.45),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderWarm, width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderWarm, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Add to Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.espressoBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        final List<String> noteParts = [];
                        for (final opt in selectedOptions.values) {
                          if (opt != 'Normal' && opt != 'Normal Sugar' && opt != 'Normal Ice') {
                            noteParts.add(opt);
                          }
                        }
                        if (selectedAddOns.isNotEmpty) {
                          noteParts.add('+ ${selectedAddOns.join(', ')}');
                        }
                        final custom = specialNoteController.text.trim();
                        if (custom.isNotEmpty) {
                          noteParts.add(custom);
                        }
                        final fullNote = noteParts.join(', ');

                        ref.read(cartProvider(widget.table.tableId).notifier).addItem(
                          item,
                          catName,
                          variant: variants.length > 1 ? selectedVariant.label : null,
                          price: unitPrice,
                          note: fullNote,
                        );

                        Navigator.pop(context);
                        _showItemAddedFeedback('${item.name} added!');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_shopping_cart, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Order • ₹${unitPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showOrderHistory(BuildContext context) {
    final role = ref.read(activeUserRoleProvider);
    final canManageKotItems = role == 'admin';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE KOTs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.maroon,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.maroon),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: widget.table.activeOrderId == null
                    ? const Center(
                        child: Text(
                          'No active order for this table',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : StreamBuilder<List<KOTModel>>(
                        stream: ref.read(kotServiceProvider).watchKOTsByOrder(widget.table.activeOrderId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.maroon));
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          final kots = snapshot.data ?? [];
                          if (kots.isEmpty) {
                            return const Center(child: Text('No KOTs found'));
                          }

                          return ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: kots.length,
                            itemBuilder: (context, index) {
                              final kot = kots[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    title: Text(
                                      'KOT #${kot.kotNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.maroon),
                                    ),
                                    subtitle: Text(
                                      'Time: ${kot.createdAt.hour}:${kot.createdAt.minute.toString().padLeft(2, '0')} | Total: ₹${kot.totalAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          children: [
                                            ...kot.items.map((item) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          '${item.qty}x ',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.maroon),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            '${item.name}${item.variant.isNotEmpty ? " (${item.variant})" : ""}',
                                                            style: const TextStyle(fontSize: 14),
                                                          ),
                                                        ),
                                                        Text(
                                                          '₹${(item.price * item.qty).toStringAsFixed(0)}',
                                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                                        ),
                                                      ],
                                                    ),
                                                    if (item.note.isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 4),
                                                        child: Align(
                                                          alignment: Alignment.centerLeft,
                                                          child: Text(
                                                            item.note,
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    if (canManageKotItems)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8),
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.end,
                                                          children: [
                                                            OutlinedButton.icon(
                                                              onPressed: _isUpdatingKotHistory
                                                                  ? null
                                                                  : () => _updateKotHistoryItem(
                                                                        kot: kot,
                                                                        item: item,
                                                                        removeWholeItem: false,
                                                                      ),
                                                              icon: const Icon(Icons.remove_circle_outline, size: 16),
                                                              label: const Text('Deduct 1'),
                                                              style: OutlinedButton.styleFrom(
                                                                foregroundColor: Colors.orange,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            OutlinedButton.icon(
                                                              onPressed: _isUpdatingKotHistory
                                                                  ? null
                                                                  : () => _updateKotHistoryItem(
                                                                        kot: kot,
                                                                        item: item,
                                                                        removeWholeItem: true,
                                                                      ),
                                                              icon: const Icon(Icons.delete_outline, size: 16),
                                                              label: const Text('Remove'),
                                                              style: OutlinedButton.styleFrom(
                                                                foregroundColor: Colors.red,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const Divider(height: 24),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: kot.isPrinted ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        kot.isPrinted ? Icons.check_circle : Icons.warning_rounded,
                                                        size: 14,
                                                        color: kot.isPrinted ? Colors.green : Colors.orange[800],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        kot.isPrinted ? 'PRINTED' : 'NOT PRINTED',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: kot.isPrinted ? Colors.green : Colors.orange[800],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () => _sendToKitchen(existingKOT: kot),
                                                  icon: const Icon(Icons.print, size: 16),
                                                  label: const Text('PRINT SLIP'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppTheme.maroon,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    minimumSize: const Size(0, 36),
                                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOBILE LAYOUT: PORTRAIT MODES ---
  Widget _buildMobileLayout() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return Column(
      children: [
        // Hide horizontal categories when global search is actively engaged
        if (!isSearching)
           SizedBox(
             height: 60,
             child: categoriesAsync.maybeWhen(
               data: (categories) {
                 final hasValidSelection = categories.any((c) => c.categoryId == _selectedCategoryId);
                 if ((_selectedCategoryId == null || !hasValidSelection) && categories.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _selectedCategoryId = categories.first.categoryId);
                    });
                 }
                 return ListView.builder(
                   scrollDirection: Axis.horizontal,
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   itemCount: categories.length,
                   itemBuilder: (context, index) {
                      final cat = categories[index];
                      final selected = _selectedCategoryId == cat.categoryId;
                      final isNonVegCat = cat.name.toLowerCase().contains('non veg');
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: isNonVegCat
                              ? Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: Colors.red[700],
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          label: Text(
                            cat.name,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? AppTheme.primaryCoffee : AppTheme.textDark,
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppTheme.primaryCoffee.withValues(alpha: 0.1),
                          backgroundColor: AppTheme.cardWhite,
                          side: BorderSide(
                            color: selected ? AppTheme.primaryCoffee : AppTheme.borderWarm,
                            width: 1,
                          ),
                          onSelected: (val) {
                            if(val) {
                              _searchController.clear();
                              ref.read(searchQueryProvider.notifier).state = '';
                              setState(() => _selectedCategoryId = cat.categoryId);
                            }
                          },
                        ),
                      );
                    },
                 );
               },
               orElse: () => const SizedBox(),
             ),
           ),
        // Item Display Canvas    
        Expanded(child: _buildItemGrid(true)),
      ],
    );
  }

  Widget _buildMobileCartBottomBar() {
    final cart = ref.watch(cartProvider(widget.table.tableId));
    final total = ref.read(cartProvider(widget.table.tableId).notifier).total;
    if (cart.isEmpty) return const SizedBox.shrink();

    int totalItems = cart.fold(0, (sum, i) => sum + i.quantity);

    return SafeArea(
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          border: const Border(top: BorderSide(color: AppTheme.borderWarm, width: 1.5)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$totalItems Items', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark.withValues(alpha: 0.6))),
                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.primaryCoffee)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showMobileCartSheet,
              icon: const Icon(Icons.shopping_cart, size: 18),
              label: const Text('SEE CART', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCoffee, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('REVIEW KOT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const Divider(thickness: 1, color: AppTheme.borderWarm, height: 24),
              Expanded(child: _buildCartList()), 
              const Divider(thickness: 1, color: AppTheme.borderWarm, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                   Consumer(builder: (c, ref, _) {
                      return Text('₹${ref.read(cartProvider(widget.table.tableId).notifier).total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee));
                   }),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Consumer(builder: (c, ref, _) {
                   final cart = ref.watch(cartProvider(widget.table.tableId));
                   final isDisabled = cart.isEmpty;
                   return Row(
                     children: [
                       Expanded(
                         flex: 3,
                         child: SizedBox(
                           height: 48,
                           child: ElevatedButton.icon(
                             onPressed: isDisabled ? null : () {
                               Navigator.pop(ctx);
                               _sendToKitchen();
                             },
                             icon: const Icon(Icons.send_rounded, size: 16),
                             label: const Text('SEND', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.primaryCoffee,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                             ),
                           ),
                         ),
                       ),
                       const SizedBox(width: 8),
                       Expanded(
                         flex: 2,
                         child: SizedBox(
                           height: 48,
                           child: ElevatedButton.icon(
                             onPressed: isDisabled ? null : () {
                               Navigator.pop(ctx);
                               _sendToKitchen(shouldPrint: true);
                             },
                             icon: const Icon(Icons.print, size: 16),
                             label: const Text('SEND & PRINT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.primaryCoffee,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                             ),
                           ),
                         ),
                       ),
                     ],
                   );
                }),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // --- DESKTOP LAYOUT: IPAD LANDSCAPE & PC ---
  Widget _buildDesktopLayout() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return Row(
      children: [
        // 1. Categories Left Panel
        Container(
          width: 140,
          decoration: const BoxDecoration(
            color: AppTheme.cardWhite,
            border: Border(right: BorderSide(color: AppTheme.borderWarm, width: 1)),
          ),
          child: categoriesAsync.when(
             data: (categories) {
               final hasValidSelection = categories.any((c) => c.categoryId == _selectedCategoryId);
               if ((_selectedCategoryId == null || !hasValidSelection) && categories.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _selectedCategoryId = categories.first.categoryId);
                    });
               }
               return ListView.builder(
                 itemCount: categories.length,
                 itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedCategoryId == cat.categoryId && !isSearching;
                    final isNonVegCat = cat.name.toLowerCase().contains('non veg');
                    return InkWell(
                      onTap: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = ''; // Clear search when clicking category naturally
                          setState(() => _selectedCategoryId = cat.categoryId);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryCoffee.withValues(alpha: 0.08) : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isSelected ? AppTheme.primaryCoffee : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isNonVegCat)
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppTheme.primaryCoffee : AppTheme.textDark,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
               );
             },
             loading: () => const Center(child: CircularProgressIndicator()),
             error: (e,s) => const Center(child: Icon(Icons.error)),
          ),
        ),
        
        // 2. Items Center Panel
        Expanded(flex: 3, child: _buildItemGrid(false)),

        // 3. Cart Right Panel (Distinct Dedicated Workspace)
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: AppTheme.cardWhite,
            border: Border(left: BorderSide(color: AppTheme.borderWarm, width: 1.5)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(-3, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Distinct KOT Header Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.backgroundWarm,
                  border: Border(bottom: BorderSide(color: AppTheme.borderWarm, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, size: 20, color: AppTheme.primaryCoffee),
                        SizedBox(width: 8),
                        Text(
                          'CURRENT KOT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.8,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    Consumer(builder: (context, ref, _) {
                      final cart = ref.watch(cartProvider(widget.table.tableId));
                      final count = cart.fold(0, (sum, i) => sum + i.quantity);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryCoffee.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count items',
                          style: const TextStyle(
                            color: AppTheme.primaryCoffee,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Expanded(child: _buildCartList()),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppTheme.cardWhite,
                  border: Border(top: BorderSide(color: AppTheme.borderWarm, width: 1.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.5,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          '₹${ref.read(cartProvider(widget.table.tableId).notifier).total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppTheme.primaryCoffee,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: ref.watch(cartProvider(widget.table.tableId)).isEmpty ? null : () => _sendToKitchen(),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('SEND', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryCoffee,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: ref.watch(cartProvider(widget.table.tableId)).isEmpty ? null : () => _sendToKitchen(shouldPrint: true),
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text('SEND & PRINT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryCoffee,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartList() {
    return Consumer(
      builder: (context, ref, child) {
        final cart = ref.watch(cartProvider(widget.table.tableId));
        if (cart.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 44, color: Colors.brown[200]),
                const SizedBox(height: 10),
                Text(
                  'Cart is empty',
                  style: TextStyle(color: Colors.brown[400], fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap items to add to order',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: cart.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final i = cart[index];
            final lineTotal = i.price * i.quantity;

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderWarm, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Item Name + Variant (Left), and Compact Stepper (Right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            if (_getDietaryType(i.item, i.categoryName) != 'veg')
                              _buildSmallDietaryBadge(_getDietaryType(i.item, i.categoryName)),
                            Text(
                              i.item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (i.variant != null && i.variant!.isNotEmpty && i.variant != 'Standard')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCaramel.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  i.variant!,
                                  style: const TextStyle(
                                    color: AppTheme.accentCaramel,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Compact Quantity Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundWarm,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderWarm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, -1),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(
                                  i.quantity == 1 ? Icons.delete_outline : Icons.remove,
                                  size: 15,
                                  color: i.quantity == 1 ? Colors.red[600] : AppTheme.primaryCoffee,
                                ),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              alignment: Alignment.center,
                              child: Text(
                                '${i.quantity}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                            ),
                            InkWell(
                              onTap: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, 1),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.add, size: 15, color: AppTheme.primaryCoffee),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Customization Note Box
                  if (i.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundWarm,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tune, size: 13, color: AppTheme.accentCaramel),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              i.note,
                              style: const TextStyle(
                                color: AppTheme.accentCaramel,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 5),

                  // Bottom Row: Price & Edit Note Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '₹${lineTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.successGreenPrice,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (i.quantity > 1)
                            Text(
                              ' (₹${i.price.toStringAsFixed(0)} ea)',
                              style: TextStyle(color: AppTheme.textDark.withValues(alpha: 0.5), fontSize: 11),
                            ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _showNoteDialog(i.cartId, i.note),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note, size: 16, color: AppTheme.accentCaramel),
                              SizedBox(width: 2),
                              Text(
                                'Edit note',
                                style: TextStyle(fontSize: 11, color: AppTheme.accentCaramel, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNoteDialog(String cartId, String currentNote) {
    final controller = TextEditingController(text: currentNote);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Special Instructions',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: AppTheme.primaryCoffee,
          decoration: InputDecoration(
            hintText: 'e.g. Less spicy, No onion',
            hintStyle: TextStyle(
              color: AppTheme.textDark.withValues(alpha: 0.45),
              fontSize: 13,
            ),
            filled: true,
            fillColor: AppTheme.backgroundWarm,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderWarm, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderWarm, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.5),
            ),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCoffee,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(cartProvider(widget.table.tableId).notifier).updateNote(cartId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}
