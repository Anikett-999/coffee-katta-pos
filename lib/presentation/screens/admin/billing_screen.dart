import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_theme.dart';
import '../../../domain/models/bill_model.dart';
import '../../../domain/models/kot_model.dart';
import '../../../domain/models/table_model.dart';
import '../../../services/billing_service.dart';
import '../../../services/pdf_service.dart';
import '../../providers/printer_provider.dart';
import '../../providers/active_branch_provider.dart';
import '../../providers/branch_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin/bill_aggregated_list.dart';

class BillingScreen extends ConsumerStatefulWidget {
  final TableModel table;
  const BillingScreen({super.key, required this.table});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final _discountController = TextEditingController(text: '0');
  final _extraChargesController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  String _selectedPaymentMode = 'Cash';
  String _discountType = 'percent';
  String _searchQuery = '';
  bool _isLoading = false;

  Map<String, dynamic>? _billPreviewData;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _extraChargesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (widget.table.activeOrderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active order found for this table')),
        );
        Navigator.pop(context);
      }
      return;
    }
    final branchId = ref.read(activeBranchIdProvider);
    if (branchId == null) throw Exception('No active branch selected');
    final billingService = BillingService(branchId: branchId);
    final preview = await billingService.previewBill(widget.table.activeOrderId!);
    if (mounted) {
      setState(() => _billPreviewData = preview);
    }
  }

  double get _total {
    if (_billPreviewData == null) return 0.0;
    double subtotal = _billPreviewData!['subtotal'];
    double discountValue = double.tryParse(_discountController.text) ?? 0;
    double extra = double.tryParse(_extraChargesController.text) ?? 0;
    if (discountValue < 0) discountValue = 0;
    if (extra < 0) extra = 0;
    double discountAmount = _discountType == 'flat'
        ? discountValue.clamp(0, subtotal)
        : (subtotal * discountValue.clamp(0, 100) / 100);
    final result = (subtotal - discountAmount) + extra;
    return result < 0 ? 0 : result;
  }

  double get _discountAmount {
    if (_billPreviewData == null) return 0.0;
    double subtotal = _billPreviewData!['subtotal'];
    double discountValue = double.tryParse(_discountController.text) ?? 0;
    if (discountValue < 0) discountValue = 0;
    return _discountType == 'flat'
        ? discountValue.clamp(0, subtotal)
        : (subtotal * discountValue.clamp(0, 100) / 100);
  }

  /// Returns an error string if the discount input is invalid, null otherwise.
  String? get _discountValidationError {
    if (_billPreviewData == null) return null;
    final subtotal = _billPreviewData!['subtotal'] as double;
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    if (discountValue < 0) return 'Discount cannot be negative';
    if (_discountType == 'percent') {
      if (discountValue > 100) return 'Percentage cannot exceed 100%';
      if (discountValue == 100) return 'This will make the bill ₹0 (100% off)';
    } else {
      if (discountValue > subtotal) {
        return 'Discount ₹${discountValue.toStringAsFixed(0)} exceeds subtotal ₹${subtotal.toStringAsFixed(0)}';
      }
      if (discountValue == subtotal) return 'This will make the bill ₹0 (full discount)';
    }
    return null;
  }

  /// Returns an error string if extra charges input is invalid, null otherwise.
  String? get _extraChargesValidationError {
    final extra = double.tryParse(_extraChargesController.text) ?? 0;
    if (extra < 0) return 'Extra charges cannot be negative';
    return null;
  }

  /// True if discount exceeds subtotal (hard block) — percentage>100 or flat>subtotal.
  bool get _hasBlockingError {
    if (_billPreviewData == null) return false;
    final subtotal = _billPreviewData!['subtotal'] as double;
    final discountValue = double.tryParse(_discountController.text) ?? 0;
    final extra = double.tryParse(_extraChargesController.text) ?? 0;
    if (discountValue < 0 || extra < 0) return true;
    if (_discountType == 'percent' && discountValue > 100) return true;
    if (_discountType == 'flat' && discountValue > subtotal) return true;
    return false;
  }

  Future<void> _handleShareDigitalBill(BillModel bill) async {
    try {
      final branchAsync = ref.read(branchProvider);
      final branch = branchAsync.value;
      if (branch == null) throw Exception('Branch data not available for sharing');

      final pdfBytes = await PdfService.generateBillPdf(bill, branch);
      final fileName = 'Bill_${bill.tableName}_${DateFormat('ddMMyy_HHmm').format(bill.createdAt)}.pdf';
      final file = await PdfService.savePdfToFile(pdfBytes, fileName);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'E-Bill for Table ${bill.tableName} at Coffee Katta',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share bill: $e')));
      }
    }
  }

  Future<void> _handleGenerateBill() async {
    if (_hasBlockingError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_discountValidationError ?? _extraChargesValidationError ?? 'Invalid input'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final branchId = ref.read(activeBranchIdProvider);
      if (branchId == null) throw Exception('No active branch selected');
      final billingService = BillingService(branchId: branchId);
      final config = ref.read(printerConfigProvider);
      final printService = ref.read(printServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      final currentUserData = await authService.getCurrentUserData();
      final cleanUserName = currentUserData?.name.trim().isNotEmpty == true
          ? currentUserData!.name.trim()
          : (currentUser?.displayName?.trim().isNotEmpty == true
              ? currentUser!.displayName!.trim()
              : (currentUser?.email?.split('@')[0] ?? 'Staff'));

      if (widget.table.activeOrderId == null) {
        throw Exception('Cannot generate bill: Missing Order ID');
      }

      final bill = await billingService.generateBill(
        orderId: widget.table.activeOrderId!,
        tableId: widget.table.tableId,
        tableName: widget.table.name,
        userName: cleanUserName,
        discountValue: double.tryParse(_discountController.text) ?? 0,
        discountType: _discountType,
        extraCharges: double.tryParse(_extraChargesController.text) ?? 0,
        payments: [Payment(mode: _selectedPaymentMode, amount: _total)],
        userId: currentUser?.uid ?? 'admin',
      );

      // Print Bill Integration
      bool printSuccess = true;
      String? printError;

      try {
        final branchAsync = ref.read(branchProvider);
        final branch = branchAsync.value;
        if (branch == null) throw Exception('Branch data not available for printing');

        final bytes = await printService.generateBillBytes(bill, branch, config.paperSize);
        printSuccess = await printService.printReceipt(bytes, config);
      } catch (printErr) {
        printSuccess = false;
        printError = printErr.toString();
      }

      if (!printSuccess && mounted) {
        final finishAnyway = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.print_disabled, color: Colors.orange),
                SizedBox(width: 8),
                Text('Print Issue'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The bill was saved to the system, but the thermal printer is unreachable.'),
                if (printError != null) Text('\nError: $printError', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                const Text('Would you like to share a digital copy via WhatsApp or finish anyway?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('RETRY PRINT'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _handleShareDigitalBill(bill);
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreenPrice,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.share),
                label: const Text('SHARE WHATSAPP'),
              ),
            ],
          ),
        );

        if (finishAnyway != true) {
          setState(() => _isLoading = false);
          return _handleGenerateBill();
        }
      }

      // Finalize and Clear Table
      await billingService.finalizeAndClearTable(widget.table.tableId, widget.table.activeOrderId!);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Bill Generated & Table Cleared!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_billPreviewData == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundWarm,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryCoffee)),
      );
    }

    final List<BillItem> items = _billPreviewData!['items'];
    final double subtotal = _billPreviewData!['subtotal'];
    final List<KOTModel> kots = _billPreviewData!['kots'];

    return Scaffold(
      backgroundColor: AppTheme.backgroundWarm,
      body: Column(
        children: [
          // Dark Espresso Branded Top Bar (as in reference image)
          _buildTopNavigationBar(context),

          // Main 3-Zone Workspace or Responsive Stack
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 950) {
                  // Desktop/Tablet 3-Panel Horizontal Layout
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Zone 1: Left KOT History Panel (~24%)
                        SizedBox(
                          width: constraints.maxWidth * 0.23,
                          child: _buildKOTHistoryPanel(kots),
                        ),
                        const SizedBox(width: 14),

                        // Zone 2: Center Bill Preview Panel (~45%)
                        Expanded(
                          flex: 5,
                          child: _buildBillPreviewPanel(items, kots.length),
                        ),
                        const SizedBox(width: 14),

                        // Zone 3: Right Settlement Panel (~32%)
                        SizedBox(
                          width: constraints.maxWidth * 0.32,
                          child: _buildSettlementPanel(subtotal, kots.length),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Mobile / Small Tablet Stacked Layout
                  return _buildMobileStackedLayout(items, subtotal, kots);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. TOP BRANDED NAVIGATION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF2A1810), // Rich dark espresso coffee header
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back to Dashboard',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),

          // Coffee Katta Logo & Script Brand
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_cafe, color: Color(0xFFE8C8A2), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Coffee Katta',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'GOOD FOOD • GREAT VIBES',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4A373).withValues(alpha: 0.9),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Divider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            width: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),

          // Screen Title Badge: Billing / Checkout
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Billing / Checkout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Table ${widget.table.name}  •  Dine-in',
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Search Bar with Ctrl + K Shortcut Badge
          Container(
            width: 280,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    cursorColor: const Color(0xFFD4A373),
                    decoration: InputDecoration(
                      hintText: 'Search menu, item or SKU...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ctrl + K',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Refresh / History Action
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            tooltip: 'Refresh KOTs & Items',
            onPressed: _loadPreview,
          ),

          // User Profile Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. ZONE 1: LEFT KOT HISTORY PANEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildKOTHistoryPanel(List<KOTModel> kots, {bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.history, size: 19, color: AppTheme.primaryCoffee),
                const SizedBox(width: 8),
                Text(
                  'KOT History (${kots.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryCoffee),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.primaryCoffee),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E1D8)),

          // KOT Items List
          Expanded(
            child: kots.isEmpty
                ? const Center(
                    child: Text(
                      'No KOTs generated yet',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: kots.length,
                    itemBuilder: (context, index) {
                      final kot = kots[index];
                      return _buildKOTCard(kot, index + 1);
                    },
                  ),
          ),

          // Botanical Watermark Branding at bottom of Left Panel (from mockup)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.spa_outlined, size: 28, color: AppTheme.accentCaramel.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Food',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color: AppTheme.primaryCoffee.withValues(alpha: 0.35),
                      ),
                    ),
                    Text(
                      'Great Vibes',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCoffee.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKOTCard(KOTModel kot, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF4EBE1), // Light warm cream circle
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCoffee,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                'KOT #${kot.kotNumber}',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(width: 8),
              // Status Badge (Printed vs Pending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kot.isPrinted
                      ? AppTheme.successGreenPrice.withValues(alpha: 0.1)
                      : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kot.isPrinted ? AppTheme.successGreenPrice : const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      kot.isPrinted ? 'Printed' : 'Pending',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: kot.isPrinted ? AppTheme.successGreenPrice : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 11, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(
                  DateFormat('hh:mm a').format(kot.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text('  •  ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                Text(
                  kot.tableName.isNotEmpty ? 'Table ${kot.tableName}' : 'Table ${widget.table.name}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          children: kot.items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF7F2EB))),
              ),
              child: Row(
                children: [
                  Text(
                    '${item.qty}x',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryCoffee),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textDark),
                    ),
                  ),
                  Text(
                    '₹${(item.price * item.qty).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. ZONE 2: CENTER BILL PREVIEW PANEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildBillPreviewPanel(List<BillItem> items, int kotCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2EB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8E1D8)),
                  ),
                  child: const Icon(Icons.receipt_outlined, color: AppTheme.primaryCoffee, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Preview',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Table ${widget.table.name}  •  $kotCount ${kotCount == 1 ? 'KOT' : 'KOTs'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const Spacer(),
                // Dine-in pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F2EB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8E1D8)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.table_restaurant_outlined, size: 14, color: AppTheme.primaryCoffee),
                      SizedBox(width: 6),
                      Text(
                        'Dine-in',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E1D8)),

          // Scrollable Items Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: BillAggregatedList(
                items: items,
                searchQuery: _searchQuery,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. ZONE 3: RIGHT SETTLEMENT PANEL
  // ─────────────────────────────────────────────────────────────
  Widget _buildSettlementPanel(double subtotal, int kotCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Settlement Header Card with Green "OPEN" Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryCoffee,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Settlement',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Table ${widget.table.name}  •  Dine-in  •  $kotCount KOTs',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreenPrice,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OPEN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Color(0xFFE8E1D8)),
                      const SizedBox(height: 14),

                      // Section 1: Order Summary
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 6),
                          const Text(
                            'Order Summary',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildSummaryRowWithIcon(
                        icon: Icons.file_upload_outlined,
                        label: 'Subtotal',
                        value: '₹${subtotal.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 6),

                      _buildSummaryRowWithIcon(
                        icon: Icons.percent_outlined,
                        label: 'Discount',
                        value: '-₹${_discountAmount.toStringAsFixed(2)}',
                        isDiscount: true,
                      ),
                      const SizedBox(height: 6),

                      _buildSummaryRowWithIcon(
                        icon: Icons.add_circle_outline,
                        label: 'Extra Charges',
                        value: '+₹${(double.tryParse(_extraChargesController.text) ?? 0).toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 16),

                      // Section 2: Total Amount Highlight Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F3EC), // Warm beige background
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE8E1D8), width: 1.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryCoffee,
                              ),
                            ),
                            Text(
                              '₹${_total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _hasBlockingError ? Colors.red.shade700 : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Discount Section
                      Row(
                        children: [
                          Icon(Icons.percent, size: 15, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 6),
                          const Text(
                            'Discount',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Segmented Discount Toggle
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _discountType = 'percent'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _discountType == 'percent' ? AppTheme.primaryCoffee : Colors.white,
                                  border: Border.all(color: _discountType == 'percent' ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8)),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.percent,
                                      size: 13,
                                      color: _discountType == 'percent' ? Colors.white : AppTheme.textDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Percentage',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _discountType == 'percent' ? FontWeight.bold : FontWeight.normal,
                                        color: _discountType == 'percent' ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _discountType = 'flat'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _discountType == 'flat' ? AppTheme.primaryCoffee : Colors.white,
                                  border: Border.all(color: _discountType == 'flat' ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8)),
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '₹',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _discountType == 'flat' ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Flat',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _discountType == 'flat' ? FontWeight.bold : FontWeight.normal,
                                        color: _discountType == 'flat' ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Discount Input Field
                      TextField(
                        controller: _discountController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          hintText: _discountType == 'flat' ? 'Discount Amount (₹)' : 'Discount Percentage (%)',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.5),
                          ),
                          suffixText: _discountType == 'flat' ? '₹' : '%',
                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                          errorText: _discountValidationError,
                          errorStyle: TextStyle(color: _hasBlockingError ? Colors.red : Colors.orange.shade800, fontSize: 11),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Section 4: Extra Charges (₹)
                      Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 15, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 6),
                          const Text(
                            'Extra Charges (₹)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: _extraChargesController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                        decoration: InputDecoration(
                          hintText: 'Additional charges or delivery (₹)',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primaryCoffee, width: 1.5),
                          ),
                          suffixText: '₹',
                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                          errorText: _extraChargesValidationError,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      // Section 5: Payment Mode
                      Row(
                        children: [
                          Icon(Icons.credit_card_outlined, size: 15, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 6),
                          const Text(
                            'Payment Mode',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 3 Payment Mode Buttons (Cash, UPI, Card)
                      Row(
                        children: [
                          _buildPaymentModeTile(mode: 'Cash', icon: Icons.payments_outlined),
                          const SizedBox(width: 8),
                          _buildPaymentModeTile(mode: 'UPI', icon: Icons.qr_code_2_outlined),
                          const SizedBox(width: 8),
                          _buildPaymentModeTile(mode: 'Card', icon: Icons.credit_card_outlined),
                        ],
                      ),
                    ],
                  ),

                  // Section 6: Primary Action Button [ PRINT & SETTLE > ]
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _hasBlockingError) ? null : _handleGenerateBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCoffee,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.print_outlined, size: 20, color: Colors.white),
                                  SizedBox(width: 10),
                                  Text(
                                    'PRINT & SETTLE',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.chevron_right, size: 20, color: Colors.white),
                                ],
                              ),
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

  Widget _buildSummaryRowWithIcon({
    required IconData icon,
    required String label,
    required String value,
    bool isDiscount = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isDiscount ? AppTheme.successGreenPrice : AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentModeTile({required String mode, required IconData icon}) {
    final isSelected = _selectedPaymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryCoffee : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.primaryCoffee,
              ),
              const SizedBox(width: 6),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. RESPONSIVE MOBILE STACKED LAYOUT
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileStackedLayout(List<BillItem> items, double subtotal, List<KOTModel> kots) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KOT History Card
              _buildKOTHistoryPanel(kots, isMobile: true),
              const SizedBox(height: 16),

              // Bill Preview
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_outlined, color: AppTheme.primaryCoffee, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Bill Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const Spacer(),
                        Text(
                          'Table ${widget.table.name}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE8E1D8)),
                    BillAggregatedList(items: items, searchQuery: _searchQuery),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom Fixed Settlement Bar for Mobile
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE8E1D8))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Payable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(
                      '₹${_total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _hasBlockingError ? Colors.red : AppTheme.primaryCoffee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showMobileAdjustmentDialog(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryCoffee,
                          side: const BorderSide(color: Color(0xFFE8E1D8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('DISCOUNT / MODE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _hasBlockingError) ? null : _handleGenerateBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryCoffee,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('PRINT & SETTLE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMobileAdjustmentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settlement Adjustments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Discount Type Toggle
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setModalState(() => _discountType = 'percent');
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _discountType == 'percent' ? AppTheme.primaryCoffee : Colors.white,
                              border: Border.all(color: _discountType == 'percent' ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8)),
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            ),
                            child: Text(
                              '%  Percentage',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _discountType == 'percent' ? Colors.white : AppTheme.textDark,
                                fontWeight: _discountType == 'percent' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setModalState(() => _discountType = 'flat');
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _discountType == 'flat' ? AppTheme.primaryCoffee : Colors.white,
                              border: Border.all(color: _discountType == 'flat' ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8)),
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            ),
                            child: Text(
                              '₹  Flat',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _discountType == 'flat' ? Colors.white : AppTheme.textDark,
                                fontWeight: _discountType == 'flat' ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _discountController,
                    decoration: InputDecoration(
                      labelText: _discountType == 'flat' ? 'Discount (₹)' : 'Discount (%)',
                      border: const OutlineInputBorder(),
                      errorText: _discountValidationError,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _extraChargesController,
                    decoration: InputDecoration(
                      labelText: 'Extra Charges (₹)',
                      border: const OutlineInputBorder(),
                      errorText: _extraChargesValidationError,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  const Text('PAYMENT MODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Row(
                    children: ['Cash', 'UPI', 'Card'].map((mode) {
                      final isSelected = _selectedPaymentMode == mode;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setModalState(() => _selectedPaymentMode = mode);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryCoffee : Colors.white,
                                border: Border.all(color: isSelected ? AppTheme.primaryCoffee : const Color(0xFFE8E1D8)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                mode,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textDark,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCoffee,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('APPLY ADJUSTMENTS', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
