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
import '../../widgets/global/editorial_background.dart';

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
  Map<String, double>? _splitAmounts;
  Map<String, double> get _safeSplitAmounts => _splitAmounts ??= {'Cash': 0.0, 'UPI': 0.0, 'Card': 0.0};
  String _discountType = 'percent';
  bool _isLoading = false;
  String _searchQuery = '';

  String get _splitSummaryText {
    final active = _safeSplitAmounts.entries.where((e) => e.value > 0).toList();
    if (active.isEmpty) return 'Tap to configure split amounts';
    return active.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(' • ');
  }

  Map<String, dynamic>? _billPreviewData;

  @override
  void initState() {
    super.initState();
    _loadPreview();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    _extraChargesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTableName(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().startsWith('table')) {
      return trimmed;
    }
    return 'Table $trimmed';
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

  double get _discountAmount {
    if (_billPreviewData == null) return 0.0;
    final subtotal = (_billPreviewData!['subtotal'] as num?)?.toDouble() ?? 0.0;
    double discountValue = double.tryParse(_discountController.text) ?? 0;
    if (discountValue < 0) discountValue = 0;
    return _discountType == 'flat'
        ? discountValue.clamp(0, subtotal)
        : (subtotal * discountValue.clamp(0, 100) / 100);
  }

  double get _extraChargesAmount {
    double extra = double.tryParse(_extraChargesController.text) ?? 0;
    return extra < 0 ? 0 : extra;
  }

  double get _total {
    if (_billPreviewData == null) return 0.0;
    final subtotal = (_billPreviewData!['subtotal'] as num?)?.toDouble() ?? 0.0;
    final result = (subtotal - _discountAmount) + _extraChargesAmount;
    return result < 0 ? 0 : result;
  }

  /// Returns an error string if the discount input is invalid, null otherwise.
  String? get _discountValidationError {
    if (_billPreviewData == null) return null;
    final subtotal = (_billPreviewData!['subtotal'] as num?)?.toDouble() ?? 0.0;
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
    final subtotal = (_billPreviewData!['subtotal'] as num?)?.toDouble() ?? 0.0;
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

      List<Payment> payments;
      if (_selectedPaymentMode == 'Split') {
        final activePayments = _safeSplitAmounts.entries
            .where((e) => e.value > 0)
            .map((e) => Payment(mode: e.key, amount: e.value))
            .toList();

        final totalAllocated = activePayments.fold(0.0, (sum, p) => sum + p.amount);
        if ((totalAllocated - _total).abs() > 0.05 || activePayments.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Split payment amounts must equal total: ₹${_total.toStringAsFixed(2)}'),
              backgroundColor: Colors.red.shade800,
            ),
          );
          _showSplitPaymentDialog();
          return;
        }
        payments = activePayments;
      } else {
        payments = [Payment(mode: _selectedPaymentMode, amount: _total)];
      }

      final bill = await billingService.generateBill(
        orderId: widget.table.activeOrderId!,
        tableId: widget.table.tableId,
        tableName: widget.table.name,
        userName: cleanUserName,
        discountValue: double.tryParse(_discountController.text) ?? 0,
        discountType: _discountType,
        extraCharges: double.tryParse(_extraChargesController.text) ?? 0,
        payments: payments,
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
                if (printError != null)
                  Text('\nError: $printError', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                const Text('Would you like to share a digital copy via WhatsApp or finish anyway?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Retry
                child: const Text('RETRY PRINT'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _handleShareDigitalBill(bill);
                  if (context.mounted) Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF287A55),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bill Generated & Table Cleared!')),
        );
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
    _splitAmounts ??= {'Cash': 0.0, 'UPI': 0.0, 'Card': 0.0};
    if (_billPreviewData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F4EF),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryCoffee),
        ),
      );
    }

    final List<BillItem> items = _billPreviewData!['items'];
    final double subtotal = (_billPreviewData!['subtotal'] as num?)?.toDouble() ?? 0.0;
    final List<KOTModel> kots = _billPreviewData!['kots'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF), // Clean warm background
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ════════════════════════════════════════════════════════
            // 1. TOP HEADER (Deep Coffee Brown #382012)
            // ════════════════════════════════════════════════════════
            _buildTopBrandedHeader(kots),

            // ════════════════════════════════════════════════════════
            // 2. MAIN 3-COLUMN WORKSPACE
            // ════════════════════════════════════════════════════════
            Expanded(
              child: EditorialBackground(
                useCreamBase: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      // Desktop / Tablet POS 3-Column Layout with proportional widths
                      final leftWidth = (constraints.maxWidth * 0.24).clamp(240.0, 300.0);
                      final rightWidth = (constraints.maxWidth * 0.30).clamp(310.0, 360.0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Column 1: KOT History
                          SizedBox(
                            width: leftWidth,
                            child: _buildKOTHistoryPanel(kots),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFFE8E1D8)),

                          // Column 2: Bill Preview (flex expansion)
                          Expanded(
                            child: _buildBillPreviewPanel(items, kots),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFFE8E1D8)),

                          // Column 3: Settlement Workspace (Compact, one view, no scrolling)
                          SizedBox(
                            width: rightWidth,
                            child: _buildSettlementPanel(subtotal, kots),
                          ),
                        ],
                      );
                    } else {
                      // Responsive Mobile Layout
                      return _buildMobileLayout(items, subtotal, kots);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER COMPONENT (Matches Reference Image)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBrandedHeader(List<KOTModel> kots) {
    return Container(
      height: 62,
      color: const Color(0xFF382012), // Deep Coffee Brown
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),

          // Coffee Katta Logo Branding
          Row(
            children: [
              const Icon(Icons.local_cafe_rounded, color: Color(0xFFF7F4EF), size: 24),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Coffee Katta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'GOOD FOOD • GREAT VIBES',
                    style: TextStyle(
                      color: Color(0xFFD4A373),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Vertical Divider
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            width: 1,
            height: 26,
            color: Colors.white24,
          ),

          // Context Badge & Table Info (Clean table name without duplication)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4A2D1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFB77945), size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Billing / Checkout',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_formatTableName(widget.table.name)}  •  Dine-in',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),

          const Spacer(),

          // Search Field ("Search menu, item or SKU..." with Ctrl + K)
          Container(
            width: 220,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C170B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white60, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search menu, item or SKU...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 11.5),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Ctrl + K',
                    style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Refresh Action
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 20),
            onPressed: _loadPreview,
            tooltip: 'Refresh Items',
          ),

          // Profile / User Action
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2C170B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COLUMN 1: KOT HISTORY PANEL (Left Workspace, Zero Overflow)
  // ─────────────────────────────────────────────────────────────
  Widget _buildKOTHistoryPanel(List<KOTModel> kots, {bool isMobile = false}) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: KOT History (count) | View All ->
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              child: Row(
                children: [
                  const Icon(Icons.history_toggle_off, color: AppTheme.textDark, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'KOT History (${kots.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _showAllKOTsModal(kots),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCoffee,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.primaryCoffee),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // KOT Cards List (Overflow-proof)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                itemCount: kots.length,
                itemBuilder: (context, index) {
                  final kot = kots[index];
                  final isLatest = index == 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isLatest ? const Color(0xFFD4A373) : const Color(0xFFE8E1D8),
                        width: isLatest ? 1.3 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showKOTDetailModal(kot, index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            // Sequential Number Circle
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F4EF),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE8E1D8)),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.primaryCoffee,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // KOT Info (Constrained with Expanded so it never overflows)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'KOT #${kot.kotNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 6,
                                            color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            kot.isPrinted ? 'Printed' : 'Pending',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 10.5, color: Colors.grey.shade600),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          '${DateFormat('hh:mm a').format(kot.createdAt)}  •  ${_formatTableName(widget.table.name)}',
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Bottom Left Botanical Watermark with "Good Food Great Vibes"
        if (!isMobile)
          Positioned(
            left: 12,
            bottom: 10,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CustomPaint(
                      size: const Size(40, 56),
                      painter: _BotanicalLeafPainter(color: const Color(0xFFB77945)),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Good Food',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'serif',
                            color: Color(0xFFB77945),
                          ),
                        ),
                        Text(
                          'Great Vibes',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'serif',
                            color: Color(0xFFB77945),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COLUMN 2: BILL PREVIEW PANEL (Center Workspace)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBillPreviewPanel(List<BillItem> items, List<KOTModel> kots) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Bill Preview | Table {name} • {count} KOTs | [Dine-in]
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppTheme.primaryCoffee, size: 18),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill Preview',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  Text(
                    '${_formatTableName(widget.table.name)}  •  ${kots.length} KOTs',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Spacer(),
              // Dine-In Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.restaurant_outlined, size: 13, color: AppTheme.primaryCoffee),
                    SizedBox(width: 4),
                    Text(
                      'Dine-in',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable Cards List
          Expanded(
            child: SingleChildScrollView(
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
  // COLUMN 3: SETTLEMENT PANEL (One View, No Scrolling Needed)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSettlementPanel(double subtotal, List<KOTModel> kots) {
    return Container(
      color: const Color(0xFFF7F4EF),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner (Deep Brown #382012 with OPEN badge) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF382012),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB77945),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settlement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatTableName(widget.table.name)}  •  Dine-in  •  ${kots.length} KOTs',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF287A55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OPEN',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Settlement Body (Responsive: fits without scroll, scrolls only if height < 440px) ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border.all(color: const Color(0xFFE8E1D8), width: 1.1),
              ),
              padding: const EdgeInsets.all(10.0),
              child: LayoutBuilder(
                builder: (context, box) {
                  final bool needScroll = box.maxHeight < 430;

                  Widget content = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: needScroll ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      // 1. Order Summary Card
                      _buildOrderSummaryCard(subtotal),
                      const SizedBox(height: 7),

                      // 2. Discount Segmented & Input
                      _buildDiscountCard(),
                      const SizedBox(height: 7),

                      // 3. Extra Charges
                      _buildExtraChargesCard(),
                      const SizedBox(height: 7),

                      // 4. Payment Mode
                      _buildPaymentModeCard(),

                      if (!needScroll) const Spacer(),
                      if (needScroll) const SizedBox(height: 10),

                      // 5. Final Action Button (PRINT & SETTLE)
                      _buildPrintAndSettleButton(),
                    ],
                  );

                  if (needScroll) {
                    return SingleChildScrollView(child: content);
                  }
                  return content;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SETTLEMENT SUB-CARDS (Compact & Ergonomic)
  // ─────────────────────────────────────────────────────────────

  // Card 1: Order Summary
  Widget _buildOrderSummaryCard(double subtotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_outlined, size: 14, color: AppTheme.primaryCoffee),
              SizedBox(width: 5),
              Text(
                'Order Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Subtotal
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Subtotal', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 3),

          // Discount
          Row(
            children: [
              const Icon(Icons.percent_rounded, size: 12, color: Color(0xFF287A55)),
              const SizedBox(width: 4),
              Text('Discount', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('- ₹${_discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF287A55))),
            ],
          ),
          const SizedBox(height: 3),

          // Extra Charges
          Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Extra Charges', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('₹${_extraChargesAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 6),

          // Total Amount Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE8E1D8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                ),
                Text(
                  '₹${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _hasBlockingError ? Colors.red : AppTheme.primaryCoffee,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Card 2: Discount
  Widget _buildDiscountCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Title on Left and Compact Composite Switch Bar on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.percent_rounded, size: 13, color: AppTheme.primaryCoffee),
                  SizedBox(width: 5),
                  Text(
                    'Discount',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark),
                  ),
                ],
              ),

              // Compact Composite Segmented Switch Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _discountType = 'percent'),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _discountType == 'percent' ? const Color(0xFF382012) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                        ),
                        child: Text(
                          '% Percentage',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _discountType == 'percent' ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _discountType = 'flat'),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _discountType == 'flat' ? const Color(0xFF382012) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                        ),
                        child: Text(
                          '₹ Flat',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _discountType == 'flat' ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Discount Input Field
          SizedBox(
            height: _discountValidationError != null ? 48 : 34,
            child: TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                labelText: _discountType == 'percent' ? 'Discount (%)' : 'Discount (₹)',
                labelStyle: const TextStyle(fontSize: 10.5, color: Colors.grey),
                suffixText: _discountType == 'percent' ? '%' : '₹',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primaryCoffee),
                filled: true,
                fillColor: const Color(0xFFFDFBF9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                ),
                errorText: _discountValidationError,
                errorStyle: TextStyle(
                  fontSize: 9,
                  height: 1,
                  color: _hasBlockingError ? Colors.red : Colors.orange.shade800,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // Card 3: Extra Charges
  Widget _buildExtraChargesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.add_circle_outline_rounded, size: 13, color: AppTheme.primaryCoffee),
              SizedBox(width: 5),
              Text(
                'Extra Charges (₹)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: _extraChargesValidationError != null ? 48 : 34,
            child: TextField(
              controller: _extraChargesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                labelText: 'Amount (₹)',
                labelStyle: const TextStyle(fontSize: 10.5, color: Colors.grey),
                suffixText: '₹',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppTheme.primaryCoffee),
                filled: true,
                fillColor: const Color(0xFFFDFBF9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
                ),
                errorText: _extraChargesValidationError,
                errorStyle: const TextStyle(fontSize: 9, height: 1, color: Colors.red),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // Card 4: Payment Mode (Cash | UPI | Card | Split)
  Widget _buildPaymentModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.payment_rounded, size: 13, color: AppTheme.primaryCoffee),
              SizedBox(width: 5),
              Text(
                'Payment Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildPaymentModeOption('Cash', Icons.payments_outlined),
              const SizedBox(width: 4),
              _buildPaymentModeOption('UPI', Icons.qr_code_2_rounded),
              const SizedBox(width: 4),
              _buildPaymentModeOption('Card', Icons.credit_card_rounded),
              const SizedBox(width: 4),
              _buildPaymentModeOption('Split', Icons.call_split_rounded),
            ],
          ),
          if (_selectedPaymentMode == 'Split') ...[
            const SizedBox(height: 5),
            InkWell(
              onTap: _showSplitPaymentDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _splitSummaryText,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryCoffee,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB77945),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.edit_rounded, size: 11, color: Color(0xFFB77945)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeOption(String mode, IconData icon) {
    final isSelected = _selectedPaymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == 'Split') {
            setState(() => _selectedPaymentMode = 'Split');
            _showSplitPaymentDialog();
          } else {
            setState(() => _selectedPaymentMode = mode);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5.5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF382012) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
              const SizedBox(width: 3),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSplitPaymentDialog() async {
    final double targetTotal = _total;

    final existingSum = _safeSplitAmounts.values.fold(0.0, (sum, val) => sum + val);
    double initialCash = _safeSplitAmounts['Cash'] ?? 0.0;
    double initialUpi = _safeSplitAmounts['UPI'] ?? 0.0;
    double initialCard = _safeSplitAmounts['Card'] ?? 0.0;

    if (existingSum == 0) {
      initialCash = targetTotal;
    }

    final cashCtrl = TextEditingController(text: initialCash > 0 ? initialCash.toStringAsFixed(0) : '');
    final upiCtrl = TextEditingController(text: initialUpi > 0 ? initialUpi.toStringAsFixed(0) : '');
    final cardCtrl = TextEditingController(text: initialCard > 0 ? initialCard.toStringAsFixed(0) : '');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double c = double.tryParse(cashCtrl.text) ?? 0.0;
            final double u = double.tryParse(upiCtrl.text) ?? 0.0;
            final double d = double.tryParse(cardCtrl.text) ?? 0.0;
            final double allocated = c + u + d;
            final double diff = allocated - targetTotal;
            final bool isBalanced = diff.abs() < 0.05 && allocated > 0;
            final double remaining = targetTotal - allocated;

            Widget buildModeInputRow({
              required String label,
              required IconData icon,
              required TextEditingController controller,
              required double currentVal,
            }) {
              final double canAddRemaining = (remaining > 0.05) ? remaining : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4EF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E1D8)),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 14, color: AppTheme.primaryCoffee),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: Colors.white,
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
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: canAddRemaining > 0
                            ? () {
                                final newVal = currentVal + canAddRemaining;
                                controller.text = newVal.toStringAsFixed(0);
                                setDialogState(() {});
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: AppTheme.primaryCoffee,
                          side: BorderSide(
                            color: canAddRemaining > 0 ? const Color(0xFFB77945) : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Fill Remainder', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4EF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.call_split_rounded, color: AppTheme.primaryCoffee, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Split Payment Allocation',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            if (_safeSplitAmounts.values.every((v) => v == 0)) {
                              setState(() => _selectedPaymentMode = 'Cash');
                            }
                            Navigator.pop(ctx);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF382012),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Due',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '₹${targetTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildModeInputRow(
                      label: 'Cash',
                      icon: Icons.payments_outlined,
                      controller: cashCtrl,
                      currentVal: c,
                    ),
                    buildModeInputRow(
                      label: 'UPI',
                      icon: Icons.qr_code_2_rounded,
                      controller: upiCtrl,
                      currentVal: u,
                    ),
                    buildModeInputRow(
                      label: 'Card',
                      icon: Icons.credit_card_rounded,
                      controller: cardCtrl,
                      currentVal: d,
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final half = (targetTotal / 2).floorToDouble();
                            cashCtrl.text = half.toStringAsFixed(0);
                            upiCtrl.text = (targetTotal - half).toStringAsFixed(0);
                            cardCtrl.clear();
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.pie_chart_outline_rounded, size: 13, color: Color(0xFFB77945)),
                          label: const Text('50/50 Cash + UPI', style: TextStyle(fontSize: 10.5, color: Color(0xFFB77945), fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            cashCtrl.clear();
                            upiCtrl.clear();
                            cardCtrl.clear();
                            setDialogState(() {});
                          },
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          child: const Text('Clear All', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isBalanced
                            ? const Color(0xFFEAF7EE)
                            : (diff > 0.05 ? const Color(0xFFFEF2F2) : const Color(0xFFFEF6EE)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBalanced
                              ? const Color(0xFF287A55)
                              : (diff > 0.05 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBalanced
                                ? Icons.check_circle_rounded
                                : (diff > 0.05 ? Icons.error_outline_rounded : Icons.info_outline_rounded),
                            size: 16,
                            color: isBalanced
                                ? const Color(0xFF287A55)
                                : (diff > 0.05 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isBalanced
                                  ? 'Exact Match: ₹${allocated.toStringAsFixed(2)} fully allocated'
                                  : (diff > 0.05
                                      ? 'Exceeds Total by ₹${diff.toStringAsFixed(2)}'
                                      : 'Remaining to allocate: ₹${remaining.toStringAsFixed(2)}'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isBalanced
                                    ? const Color(0xFF287A55)
                                    : (diff > 0.05 ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (_safeSplitAmounts.values.every((v) => v == 0)) {
                                setState(() => _selectedPaymentMode = 'Cash');
                              }
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textDark,
                              side: const BorderSide(color: Color(0xFFE8E1D8)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isBalanced
                                ? () {
                                    setState(() {
                                      _splitAmounts = {
                                        'Cash': c,
                                        'UPI': u,
                                        'Card': d,
                                      };
                                      _selectedPaymentMode = 'Split';
                                    });
                                    Navigator.pop(ctx);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF382012),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Confirm Split', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Card 5: Final Settlement Action Button
  Widget _buildPrintAndSettleButton() {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: (_isLoading || _hasBlockingError) ? null : _handleGenerateBill,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF382012),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.print_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'PRINT & SETTLE',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white70),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RESPONSIVE MOBILE LAYOUT (Stacked)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(List<BillItem> items, double subtotal, List<KOTModel> kots) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Collapsible KOT History
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.history_toggle_off, color: AppTheme.primaryCoffee),
                  title: Text(
                    'KOT HISTORY (${kots.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: kots.length,
                      itemBuilder: (context, index) {
                        final kot = kots[index];
                        return ListTile(
                          dense: true,
                          title: Text('KOT #${kot.kotNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(DateFormat('hh:mm a').format(kot.createdAt)),
                          trailing: Text(
                            kot.isPrinted ? 'Printed' : 'Pending',
                            style: TextStyle(
                              color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          onTap: () => _showKOTDetailModal(kot, index + 1),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Bill Preview Header
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryCoffee, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'BILL PREVIEW (${items.length} ITEMS)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              BillAggregatedList(items: items, searchQuery: _searchQuery),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Sticky Bottom Mobile Settlement Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '₹${_total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _hasBlockingError ? Colors.red : AppTheme.primaryCoffee,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () => _showMobileAdjustmentModal(subtotal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryCoffee,
                      side: const BorderSide(color: Color(0xFFE8E1D8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('DISCOUNT / MODE', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPrintAndSettleButton(),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODALS & HELPERS
  // ─────────────────────────────────────────────────────────────

  void _showKOTDetailModal(KOTModel kot, int sequence) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'KOT #$sequence (Ticket #${kot.kotNumber})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const Spacer(),
                Text(
                  kot.isPrinted ? 'Printed' : 'Pending',
                  style: TextStyle(
                    color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...kot.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.qty}x ${item.name}'),
                      Text('₹${(item.price * item.qty).toStringAsFixed(0)}'),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showAllKOTsModal(List<KOTModel> kots) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F4EF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All KOTs for ${_formatTableName(widget.table.name)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: kots.length,
                  itemBuilder: (context, index) {
                    final kot = kots[index];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE8E1D8)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('KOT #${kot.kotNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(DateFormat('hh:mm a').format(kot.createdAt)),
                              ],
                            ),
                            const Divider(height: 12),
                            ...kot.items.map((i) => Text('${i.qty}x ${i.name}')),
                          ],
                        ),
                      ),
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

  void _showMobileAdjustmentModal(double subtotal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Discount & Payment Adjustments',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDiscountCard(),
                  const SizedBox(height: 8),
                  _buildExtraChargesCard(),
                  const SizedBox(height: 8),
                  _buildPaymentModeCard(),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF382012),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('APPLY & CLOSE'),
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

/// Subtle botanical leaf painter for the bottom-left corner of KOT History panel
class _BotanicalLeafPainter extends CustomPainter {
  final Color color;

  const _BotanicalLeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Stem
    final stem = Path()
      ..moveTo(w * 0.1, h * 0.95)
      ..quadraticBezierTo(w * 0.3, h * 0.5, w * 0.8, h * 0.05);
    canvas.drawPath(stem, paint);

    // Leaf 1
    final leaf1 = Path()
      ..moveTo(w * 0.25, h * 0.7)
      ..quadraticBezierTo(w * 0.05, h * 0.58, w * 0.2, h * 0.5)
      ..quadraticBezierTo(w * 0.3, h * 0.58, w * 0.25, h * 0.7);
    canvas.drawPath(leaf1, paint);

    // Leaf 2
    final leaf2 = Path()
      ..moveTo(w * 0.4, h * 0.5)
      ..quadraticBezierTo(w * 0.65, h * 0.42, w * 0.55, h * 0.3)
      ..quadraticBezierTo(w * 0.42, h * 0.38, w * 0.4, h * 0.5);
    canvas.drawPath(leaf2, paint);

    // Leaf 3
    final leaf3 = Path()
      ..moveTo(w * 0.55, h * 0.3)
      ..quadraticBezierTo(w * 0.35, h * 0.2, w * 0.5, h * 0.12)
      ..quadraticBezierTo(w * 0.6, h * 0.2, w * 0.55, h * 0.3);
    canvas.drawPath(leaf3, paint);
  }

  @override
  bool shouldRepaint(covariant _BotanicalLeafPainter oldDelegate) => oldDelegate.color != color;
}
