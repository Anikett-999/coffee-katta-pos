/// PROTECTED MODULE: WAITER
/// DO NOT MODIFY this file for Admin feature development.
/// Contact system architect before changing core waiter workflows.

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

class CartItem {
  final String cartId;
  final Item item;
  final String categoryName;
  final int quantity;
  final String? variant;
  final String note;

  CartItem({
    required this.cartId,
    required this.item,
    required this.categoryName,
    required this.quantity,
    this.variant,
    this.note = '',
  });

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      cartId: cartId,
      item: item,
      categoryName: categoryName,
      quantity: quantity ?? this.quantity,
      variant: variant,
      note: note ?? this.note,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Item item, String categoryName, {String? variant}) {
    final index = state.indexWhere((i) => i.item.itemId == item.itemId && i.variant == variant);
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
          variant: variant,
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

  double get total => state.fold(0, (sum, i) => sum + (i.item.price * i.quantity));
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
                price: i.item.price,
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

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (item.variants.isNotEmpty) {
                    _showVariantDialog(item, catName);
                  } else {
                    ref.read(cartProvider(widget.table.tableId).notifier).addItem(item, catName);
                    if (isMobile) {
                      _showItemAddedFeedback(item.name);
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (catName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(catName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0.5)),
                      ],
                      const SizedBox(height: 8),
                      Text('₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.deepGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                      if (item.variants.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Text('Has Variants', style: TextStyle(color: Colors.grey, fontSize: 10)),
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
            duration: const Duration(milliseconds: 500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      void _showVariantDialog(Item item, String catName) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Select Variant for ${item.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: item.variants
                  .map((v) => ListTile(
                        title: Text(v),
                        onTap: () {
                          ref.read(cartProvider(widget.table.tableId).notifier).addItem(item, catName, variant: v);
                          Navigator.pop(context);
                          _showItemAddedFeedback('${item.name} ($v)');
                        },
                      ))
                  .toList(),
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
          width: 350,
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
        if(cart.isEmpty) return const Center(child: Text('Add items from the menu.', style: TextStyle(color: Colors.grey, fontSize: 18)));

        return ListView.separated(
          itemCount: cart.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final i = cart[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.item.name, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(i.categoryName.toUpperCase(), 
                              style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    if (i.variant != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.maroon.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(i.variant!, 
                            style: const TextStyle(color: AppTheme.maroon, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${(i.item.price * i.quantity).toStringAsFixed(0)}', 
                      style: const TextStyle(color: AppTheme.deepGreen, fontSize: 15, fontWeight: FontWeight.w600)),
                    if (i.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Note: ${i.note}', 
                          style: const TextStyle(color: Colors.orange, fontSize: 13, fontStyle: FontStyle.italic)),
                      ),
                    TextButton.icon(
                      onPressed: () => _showNoteDialog(i.cartId, i.note),
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: Text(i.note.isEmpty ? 'Add Note' : 'Edit Note', style: const TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppTheme.maroon,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 24), 
                        onPressed: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, -1)
                    ),
                    Container(
                        alignment: Alignment.center,
                        width: 32,
                        child: Text('${i.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    ),
                    IconButton(
                        icon: const Icon(Icons.add_circle, size: 24), 
                        color: AppTheme.maroon, 
                        onPressed: () => ref.read(cartProvider(widget.table.tableId).notifier).updateQuantity(i.cartId, 1)
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
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
