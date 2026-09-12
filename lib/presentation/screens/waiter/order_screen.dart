/// COFFEE KATTA POS: WAITER ORDERING & BEVERAGE CUSTOMIZER MODULE
/// Authorized for Coffee Katta Cafe Workflow & Beverage Customization.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coffee_katta_pos/core/app_theme.dart';
import 'package:coffee_katta_pos/domain/models/category.dart';
import 'package:coffee_katta_pos/domain/models/item.dart';
import 'package:coffee_katta_pos/domain/models/table_model.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/services/menu_service.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/presentation/providers/auth_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/printer_provider.dart';
import 'package:coffee_katta_pos/presentation/providers/active_branch_provider.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/profile_menu.dart';
import 'package:coffee_katta_pos/presentation/widgets/global/base_widgets.dart'; // Added for LoadingIndicator
import 'package:coffee_katta_pos/presentation/widgets/global/editorial_background.dart';
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

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(menuServiceProvider).watchCategories();
});

// Load the entire menu into memory so global search is instant (Zero Latency)
final allItemsProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(menuServiceProvider).watchAvailableItems();
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
        .map((i) => i.cartId == cartId ? i.copyWith(quantity: i.quantity + delta) : i)
        .where((i) => i.quantity > 0)
        .toList();
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

  @override
  void initState() {
    super.initState();
    // Wipe any lingering search state when navigating to a new table
    Future.microtask(() => ref.read(searchQueryProvider.notifier).state = '');
    
    // Auto-open history if requested (e.g. from TableCard "Print Pending" action)
    if (widget.initialIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showOrderHistory(context);
      });
    }
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
            final shouldDiscard = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard Cart?'),
                content: const Text(
                    'You have items in your cart. Leaving this screen will keep them saved for this table. Do you want to go back?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Go Back',
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              ),
            );
            if (shouldDiscard == true && context.mounted) {
              ref.read(cartProvider(widget.table.tableId).notifier).clear();
              Navigator.of(context).pop();
            }
          },
          child: EditorialBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text('Table $tableName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.maroon)),
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.maroon),
                onPressed: () => _handleBack(context, ref),
              ),
              actions: [
                // Search Input
                Container(
                  width: isDesktop ? 300 : MediaQuery.of(context).size.width * 0.35,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: CupertinoSearchTextField(
                    placeholder: 'Search',
                    onChanged: (val) =>
                        ref.read(searchQueryProvider.notifier).state = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history, color: AppTheme.maroon),
                  tooltip: 'View Sent Items',
                  onPressed: () => _showOrderHistory(context),
                ),
                const ProfileMenu(),
              ],
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
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: LoadingIndicator(message: _processingStatus),
              ),
            ),
          ),
      ],
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

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: isMobile ? 180 : 200, // Optimize sizing for phone real-estate
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 0.9 : 1.2,
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
            final isNonVeg = catName.contains('Non Veg') ||
                item.name.toLowerCase().contains('chicken');

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _showItemCustomizer(item, catName);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: isNonVeg ? Colors.red[700] : Colors.green[700],
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              item.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      if (catName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(catName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0.5)),
                      ],
                      const SizedBox(height: 8),
                      Text('₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.deepGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                      if (item.variants.length > 1) ...[
                        const SizedBox(height: 4),
                        const Text('Has Sizes / Variants', style: TextStyle(color: AppTheme.warmCaramel, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
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

    final isFoodOrSide = catName.contains('Starter') ||
        catName.contains('Sides') ||
        item.categoryId.contains('starter') ||
        item.categoryId.contains('sides');

    final isNonVeg = catName.contains('Non Veg') ||
        item.name.toLowerCase().contains('chicken');

    // Profile Settings
    String selectedOption = isCoffee
        ? 'Normal Sugar'
        : (isShakeOrTea ? 'Normal Ice' : 'Normal');

    final List<String> primaryOptions = isCoffee
        ? ['No Sugar', 'Less Sugar', 'Normal Sugar']
        : (isShakeOrTea
            ? ['Normal Ice', 'Less Ice', 'Extra Chilled']
            : ['Normal', 'Extra Crispy', 'Less Spicy']);

    final String primaryLabel = isCoffee
        ? 'SUGAR LEVEL'
        : (isShakeOrTea ? 'ICE / CHILL LEVEL' : 'PREPARATION STYLE');

    final List<Map<String, dynamic>> addOnOptions = isCoffee
        ? [
            {'name': 'Extra Espresso Shot', 'price': 30.0},
            {'name': 'Extra Milk / Cream', 'price': 15.0},
            {'name': 'Extra Ice Cream', 'price': 30.0},
            {'name': 'Whipped Cream', 'price': 25.0},
          ]
        : (isShakeOrTea
            ? [
                {'name': 'Extra Ice Cream Scoop', 'price': 30.0},
                {'name': 'Whipped Cream', 'price': 25.0},
                {'name': 'Chocolate Drizzle', 'price': 20.0},
              ]
            : [
                {'name': 'Extra Cheese Dip', 'price': 25.0},
                {'name': 'Peri Peri Seasoning', 'price': 15.0},
                {'name': 'Mayo Dip', 'price': 15.0},
              ]);

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
          for (final opt in addOnOptions) {
            if (selectedAddOns.contains(opt['name'])) {
              addOnsTotal += (opt['price'] as double);
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
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: isNonVeg ? Colors.red[700] : Colors.green[700],
                                    shape: BoxShape.circle,
                                  ),
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
                                  isNonVeg ? '• Non-Veg' : '• Veg',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isNonVeg ? Colors.red[700] : Colors.green[800],
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

                  // 2. Primary Option (Sugar / Chill / Prep)
                  Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppTheme.warmCaramel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: primaryOptions.map((opt) {
                      final isSelected = selectedOption == opt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Center(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : AppTheme.espressoBrown,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.warmCaramel,
                            backgroundColor: Colors.white,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => selectedOption = opt);
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 3. Optional Add-ons
                  const Text(
                    'OPTIONAL ADD-ONS',
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
                    children: addOnOptions.map((opt) {
                      final name = opt['name'] as String;
                      final price = opt['price'] as double;
                      final isChecked = selectedAddOns.contains(name);
                      return FilterChip(
                        label: Text(
                          '+ $name (₹${price.toStringAsFixed(0)})',
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
                              selectedAddOns.add(name);
                            } else {
                              selectedAddOns.remove(name);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 4. Special Instructions TextField
                  const Text(
                    'SPECIAL INSTRUCTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: AppTheme.warmCaramel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: specialNoteController,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.brown[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.espressoBrown, width: 1.5),
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
                        if (selectedOption != 'Normal') {
                          noteParts.add(selectedOption);
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

      void _showVariantDialog(Item item, String catName) {
        final List<ParsedVariant> variants = item.variants
            .map((v) => ParsedVariant.fromString(v))
            .toList();

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.latteCream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECT SIZE / VARIANT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppTheme.warmCaramel,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.espressoBrown,
                            ),
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
                const Divider(height: 20),
                ...variants.map((v) {
                  final double unitPrice = item.price + v.extraPrice;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.brown[100]!),
                    ),
                    child: ListTile(
                      title: Text(
                        v.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.espressoBrown),
                      ),
                      subtitle: v.extraPrice > 0
                          ? Text('+₹${v.extraPrice.toStringAsFixed(0)} upgrade',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12))
                          : null,
                      trailing: Text(
                        '₹${unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.deepGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      onTap: () {
                        ref.read(cartProvider(widget.table.tableId).notifier).addItem(
                          item,
                          catName,
                          variant: v.label,
                          price: unitPrice,
                        );
                        Navigator.pop(context);
                        _showItemAddedFeedback('${item.name} (${v.label})');
                      },
                    ),
                  );
                }).toList(),
                const SizedBox(height: 10),
              ],
            ),
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
                  color: Colors.grey.withOpacity(0.3),
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
                                            }).toList(),
                                            const Divider(height: 24),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: kot.isPrinted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
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
                 if (_selectedCategoryId == null && categories.isNotEmpty) {
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
                     return Padding(
                       padding: const EdgeInsets.only(right: 8),
                       child: ChoiceChip(
                         label: Text(cat.name, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                         selected: selected,
                         selectedColor: AppTheme.maroon.withOpacity(0.1),
                         onSelected: (val) {
                           if(val) setState(() => _selectedCategoryId = cat.categoryId);
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
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$totalItems Items', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.maroon)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showMobileCartSheet,
              icon: const Icon(Icons.shopping_cart),
              label: const Text('SEE CART'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8, // Take up 80% of screen giving breathing room
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('REVIEW KOT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(thickness: 2, height: 30),
              Expanded(child: _buildCartList()), 
              const Divider(thickness: 2, height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('GRAND TOTAL', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   Consumer(builder: (c, ref, _) {
                      return Text('₹${ref.read(cartProvider(widget.table.tableId).notifier).total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.maroon));
                   }),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: Consumer(builder: (c, ref, _) {
                   final cart = ref.watch(cartProvider(widget.table.tableId));
                   final isDisabled = cart.isEmpty;
                   return Row(
                     children: [
                       Expanded(
                         flex: 3,
                         child: SizedBox(
                           height: 60,
                           child: ElevatedButton(
                             onPressed: isDisabled ? null : () {
                               Navigator.pop(ctx);
                               _sendToKitchen();
                             },
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.deepGreen,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                             ),
                             child: const Text('SEND TO KITCHEN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                           ),
                         ),
                       ),
                       const SizedBox(width: 10),
                       Expanded(
                         flex: 2,
                         child: SizedBox(
                           height: 60,
                           child: ElevatedButton.icon(
                             onPressed: isDisabled ? null : () {
                               Navigator.pop(ctx);
                               _sendToKitchen(shouldPrint: true);
                             },
                             icon: const Icon(Icons.print, size: 20),
                             label: const Text('SEND & PRINT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.maroon,
                               foregroundColor: Colors.white,
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      }
    );
  }

  // --- DESKTOP LAYOUT: IPAD LANDSCAPE & PC ---
  Widget _buildDesktopLayout() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isSearching = ref.watch(searchQueryProvider).isNotEmpty;

    return Row(
      children: [
        // 1. Categories Left Panel
        SizedBox(
          width: 140,
          child: categoriesAsync.when(
             data: (categories) {
               if (_selectedCategoryId == null && categories.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _selectedCategoryId = categories.first.categoryId);
                    });
               }
               return ListView.builder(
                 itemCount: categories.length,
                 itemBuilder: (context, index) {
                   final cat = categories[index];
                   final isSelected = _selectedCategoryId == cat.categoryId && !isSearching;
                   return InkWell(
                     onTap: () {
                         ref.read(searchQueryProvider.notifier).state = ''; // Clear search when clicking category naturally
                         setState(() => _selectedCategoryId = cat.categoryId);
                     },
                     child: Container(
                       padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                        color: isSelected ? AppTheme.maroon.withOpacity(0.1) : null,
                       child: Text(
                         cat.name,
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.maroon : null,
                         ),
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
        const VerticalDivider(width: 1),
        
        // 2. Items Center Panel
        Expanded(flex: 3, child: _buildItemGrid(false)),
        const VerticalDivider(width: 1),

        // 3. Cart Right Panel (Persistent)
        SizedBox(
          width: 380,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text('CURRENT KOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              Expanded(child: _buildCartList()),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        Text('₹${ref.read(cartProvider(widget.table.tableId).notifier).total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: AppTheme.maroon)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 58,
                            child: ElevatedButton(
                              onPressed: ref.watch(cartProvider(widget.table.tableId)).isEmpty ? null : () => _sendToKitchen(),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deepGreen, foregroundColor: Colors.white),
                              child: const Text('SEND TO KITCHEN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 58,
                            child: ElevatedButton.icon(
                              onPressed: ref.watch(cartProvider(widget.table.tableId)).isEmpty ? null : () => _sendToKitchen(shouldPrint: true),
                              icon: const Icon(Icons.print, size: 18),
                              label: const Text('SEND & PRINT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon, foregroundColor: Colors.white),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEADBCE), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
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
                            Text(
                              i.item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.espressoBrown,
                              ),
                            ),
                            if (i.variant != null && i.variant!.isNotEmpty && i.variant != 'Standard')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.warmCaramel.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  i.variant!,
                                  style: const TextStyle(
                                    color: AppTheme.warmCaramel,
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
                          color: const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2D7CC)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, -1),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.remove, size: 15, color: AppTheme.espressoBrown),
                              ),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              alignment: Alignment.center,
                              child: Text(
                                '${i.quantity}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.espressoBrown),
                              ),
                            ),
                            InkWell(
                              onTap: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, 1),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                child: Icon(Icons.add, size: 15, color: AppTheme.espressoBrown),
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
                        color: const Color(0xFFFAF3EC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF0E0D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tune, size: 13, color: AppTheme.warmCaramel),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              i.note,
                              style: const TextStyle(
                                color: AppTheme.warmCaramel,
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
                              color: AppTheme.deepGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (i.quantity > 1)
                            Text(
                              ' (₹${i.price.toStringAsFixed(0)} ea)',
                              style: TextStyle(color: Colors.brown[400], fontSize: 11),
                            ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _showNoteDialog(i.cartId, i.note),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note, size: 16, color: Colors.brown[400]),
                              const SizedBox(width: 2),
                              Text(
                                i.note.isEmpty ? 'Add note' : 'Edit note',
                                style: TextStyle(fontSize: 11, color: Colors.brown[600], fontWeight: FontWeight.w500),
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
        title: const Text('Special Instructions'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Less spicy, No onion'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
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
