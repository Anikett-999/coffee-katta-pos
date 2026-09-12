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
  String _discountType = 'percent';
  bool _isLoading = false;
  String _searchQuery = '';

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
                useCreamBase: false, // already on cream background
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      // Desktop / Tablet POS 3-Column Layout
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Column 1: KOT History (21% width)
                          SizedBox(
                            width: constraints.maxWidth * 0.21,
                            child: _buildKOTHistoryPanel(kots),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFFE8E1D8)),

                          // Column 2: Bill Preview (48% width)
                          Expanded(
                            child: _buildBillPreviewPanel(items, kots),
                          ),
                          const VerticalDivider(width: 1, color: Color(0xFFE8E1D8)),

                          // Column 3: Settlement Workspace (31% width)
                          SizedBox(
                            width: constraints.maxWidth * 0.31,
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
      height: 64,
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
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: 1,
            height: 28,
            color: Colors.white24,
          ),

          // Context Badge & Table Info
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4A2D1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFB77945), size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Billing / Checkout',
                style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'Table ${widget.table.name}  •  Dine-in',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),

          const Spacer(),

          // Search Field ("Search menu, item or SKU..." with Ctrl + K)
          Container(
            width: 250,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C170B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white60, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'Search menu, item or SKU...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Ctrl + K',
                    style: TextStyle(color: Colors.white60, fontSize: 9.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Refresh Action
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70, size: 22),
            onPressed: _loadPreview,
            tooltip: 'Refresh Items',
          ),

          // Profile / User Action
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2C170B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF5A3825)),
            ),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 19),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // COLUMN 1: KOT HISTORY PANEL (Left Workspace)
  // ─────────────────────────────────────────────────────────────
  Widget _buildKOTHistoryPanel(List<KOTModel> kots, {bool isMobile = false}) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: KOT History (count) | View All ->
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.history_toggle_off, color: AppTheme.textDark, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'KOT History (${kots.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryCoffee,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: AppTheme.primaryCoffee),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // KOT Cards List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: kots.length,
                itemBuilder: (context, index) {
                  final kot = kots[index];
                  final isLatest = index == 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLatest ? const Color(0xFFD4A373) : const Color(0xFFE8E1D8),
                        width: isLatest ? 1.4 : 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showKOTDetailModal(kot, index + 1),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Sequential Number Circle
                            Container(
                              width: 32,
                              height: 32,
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
                                    fontSize: 13,
                                    color: AppTheme.primaryCoffee,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // KOT Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'KOT #${kot.kotNumber}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Status Dot & Text
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 7,
                                            color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            kot.isPrinted ? 'Printed' : 'Pending',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: kot.isPrinted ? const Color(0xFF287A55) : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 11.5, color: Colors.grey.shade600),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${DateFormat('hh:mm a').format(kot.createdAt)}  •  Table ${widget.table.name}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
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
            bottom: 12,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CustomPaint(
                      size: const Size(50, 70),
                      painter: _BotanicalLeafPainter(color: const Color(0xFFB77945)),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Good Food',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'serif',
                            color: Color(0xFFB77945),
                          ),
                        ),
                        Text(
                          'Great Vibes',
                          style: TextStyle(
                            fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Bill Preview | Table {name} • {count} KOTs | [Dine-in]
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppTheme.primaryCoffee, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill Preview',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  Text(
                    'Table ${widget.table.name}  •  ${kots.length} KOTs',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const Spacer(),
              // Dine-In Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4EF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.restaurant_outlined, size: 14, color: AppTheme.primaryCoffee),
                    SizedBox(width: 5),
                    Text(
                      'Dine-in',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCoffee,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
  // COLUMN 3: SETTLEMENT PANEL (Right Dedicated Workspace)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSettlementPanel(double subtotal, List<KOTModel> kots) {
    return Container(
      color: const Color(0xFFF7F4EF),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Banner (Deep Brown #382012 with OPEN badge) ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF382012),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB77945),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settlement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Table ${widget.table.name}  •  Dine-in  •  ${kots.length} KOTs',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF287A55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OPEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Settlement Body Cards ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border.all(color: const Color(0xFFE8E1D8), width: 1.2),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Order Summary Card
                    _buildOrderSummaryCard(subtotal),
                    const SizedBox(height: 12),

                    // 2. Discount Segmented & Input
                    _buildDiscountCard(),
                    const SizedBox(height: 12),

                    // 3. Extra Charges
                    _buildExtraChargesCard(),
                    const SizedBox(height: 12),

                    // 4. Payment Mode
                    _buildPaymentModeCard(),
                    const SizedBox(height: 16),

                    // 5. Final Action Button (PRINT & SETTLE)
                    _buildPrintAndSettleButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SETTLEMENT SUB-CARDS
  // ─────────────────────────────────────────────────────────────

  // Card 1: Order Summary
  Widget _buildOrderSummaryCard(double subtotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.receipt_outlined, size: 16, color: AppTheme.primaryCoffee),
              SizedBox(width: 6),
              Text(
                'Order Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subtotal
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Subtotal', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 6),

          // Discount
          Row(
            children: [
              const Icon(Icons.percent_rounded, size: 13, color: Color(0xFF287A55)),
              const SizedBox(width: 4),
              Text('Discount', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('- ₹${_discountAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF287A55))),
            ],
          ),
          const SizedBox(height: 6),

          // Extra Charges
          Row(
            children: [
              Icon(Icons.add_circle_outline_rounded, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text('Extra Charges', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
              const Spacer(),
              Text('₹${_extraChargesAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 12),

          // Total Amount Highlight Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E1D8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.percent_rounded, size: 15, color: AppTheme.primaryCoffee),
              SizedBox(width: 6),
              Text(
                'Discount',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Segmented Toggle (% Percentage | ₹ Flat)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'percent'),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _discountType == 'percent' ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      border: Border.all(
                        color: _discountType == 'percent' ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
                      ),
                    ),
                    child: Text(
                      '% Percentage',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _discountType == 'percent' ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'flat'),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _discountType == 'flat' ? const Color(0xFF382012) : const Color(0xFFF7F4EF),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      border: Border.all(
                        color: _discountType == 'flat' ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
                      ),
                    ),
                    child: Text(
                      '₹ Flat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _discountType == 'flat' ? Colors.white : AppTheme.textDark,
                      ),
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
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              labelText: _discountType == 'percent' ? 'Discount (%)' : 'Discount (₹)',
              labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              suffixText: _discountType == 'percent' ? '%' : '₹',
              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
              filled: true,
              fillColor: const Color(0xFFFDFBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
              ),
              errorText: _discountValidationError,
              errorStyle: TextStyle(
                fontSize: 10.5,
                color: _hasBlockingError ? Colors.red : Colors.orange.shade800,
              ),
            ),
            onChanged: (_) => setState(() {}),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.add_circle_outline_rounded, size: 15, color: AppTheme.primaryCoffee),
              SizedBox(width: 6),
              Text(
                'Extra Charges (₹)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _extraChargesController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              labelText: 'Amount (₹)',
              labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              suffixText: '₹',
              suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryCoffee),
              filled: true,
              fillColor: const Color(0xFFFDFBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E1D8)),
              ),
              errorText: _extraChargesValidationError,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // Card 4: Payment Mode (Cash | UPI | Card)
  Widget _buildPaymentModeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E1D8)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.payment_rounded, size: 15, color: AppTheme.primaryCoffee),
              SizedBox(width: 6),
              Text(
                'Payment Mode',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentModeOption('Cash', Icons.payments_outlined),
              const SizedBox(width: 8),
              _buildPaymentModeOption('UPI', Icons.qr_code_2_rounded),
              const SizedBox(width: 8),
              _buildPaymentModeOption('Card', Icons.credit_card_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeOption(String mode, IconData icon) {
    final isSelected = _selectedPaymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF382012) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF382012) : const Color(0xFFE8E1D8),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
              const SizedBox(width: 5),
              Text(
                mode,
                style: TextStyle(
                  fontSize: 12,
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

  // Card 5: Final Settlement Action Button
  Widget _buildPrintAndSettleButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: (_isLoading || _hasBlockingError) ? null : _handleGenerateBill,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF382012),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.print_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'PRINT & SETTLE',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white70),
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
            padding: const EdgeInsets.all(14),
            children: [
              // Collapsible KOT History
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E1D8)),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.history_toggle_off, color: AppTheme.primaryCoffee),
                  title: Text(
                    'KOT HISTORY (${kots.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark),
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
              const SizedBox(height: 14),

              // Bill Preview Header
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryCoffee, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'BILL PREVIEW (${items.length} ITEMS)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              BillAggregatedList(items: items, searchQuery: _searchQuery),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Sticky Bottom Mobile Settlement Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
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
                      const Text('Total Amount', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
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
                  OutlinedButton(
                    onPressed: () => _showMobileAdjustmentModal(subtotal),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryCoffee,
                      side: const BorderSide(color: Color(0xFFE8E1D8)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('DISCOUNT / MODE'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                'All KOTs for Table ${widget.table.name}',
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
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Discount & Payment Adjustments',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  _buildDiscountCard(),
                  const SizedBox(height: 12),
                  _buildExtraChargesCard(),
                  const SizedBox(height: 12),
                  _buildPaymentModeCard(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF382012),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ..strokeWidth = 1.2
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
