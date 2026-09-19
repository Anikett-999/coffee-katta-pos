import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/bill_model.dart';
import '../../../../../services/pdf_service.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../providers/printer_provider.dart';
import '../../../../providers/analytics_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../../services/billing_service.dart';

class InvoiceAuditLogTab extends ConsumerStatefulWidget {
  final String branchId;

  const InvoiceAuditLogTab({
    super.key,
    required this.branchId,
  });

  @override
  ConsumerState<InvoiceAuditLogTab> createState() => _InvoiceAuditLogTabState();
}

class _InvoiceAuditLogTabState extends ConsumerState<InvoiceAuditLogTab> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _paymentFilter = 'ALL';
  String _statusFilter = 'ALL'; // ALL | ACTIVE | VOIDED

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final billsAsync = ref.watch(billsForPeriodProvider(widget.branchId));
    final branchAsync = ref.watch(branchProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return billsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.espressoBrown),
      ),
      error: (err, _) => Center(
        child: Text('Failed to load bills: $err', style: GoogleFonts.epilogue(color: Colors.red)),
      ),
      data: (bills) {
        final q = _searchQuery.trim().toLowerCase();
        final filteredBills = bills.where((b) {
          final matchesSearch = q.isEmpty ||
              b.billId.toLowerCase().contains(q) ||
              b.tableName.toLowerCase().contains(q) ||
              b.userName.toLowerCase().contains(q) ||
              b.items.any((item) => item.name.toLowerCase().contains(q)) ||
              b.payments.any((pay) => pay.mode.toLowerCase().contains(q));

          if (!matchesSearch) return false;

          if (_paymentFilter != 'ALL') {
            final hasMode = b.payments.any((p) => p.mode.toLowerCase() == _paymentFilter.toLowerCase());
            if (!hasMode) return false;
          }

          if (_statusFilter == 'ACTIVE' && b.isVoided) return false;
          if (_statusFilter == 'VOIDED' && !b.isVoided) return false;

          return true;
        }).toList();

        final totalCount = filteredBills.length;
        final activeCount = filteredBills.where((b) => !b.isVoided).length;
        final voidedCount = filteredBills.where((b) => b.isVoided).length;
        final netRevenue = filteredBills.where((b) => !b.isVoided).fold(0.0, (acc, b) => acc + b.total);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderWarm, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.epilogue(fontSize: 13, color: AppTheme.textDark),
                    decoration: InputDecoration(
                      hintText: 'Search by Invoice (INV-...), Table, Cashier, Item, or Payment...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.espressoBrown),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderWarm),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderWarm),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.espressoBrown, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundWarm.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text('Payment: ', style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.espressoBrown)),
                        const SizedBox(width: 4),
                        ...['ALL', 'CASH', 'UPI', 'CARD'].map((mode) {
                          final isSelected = _paymentFilter == mode;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(mode),
                              selected: isSelected,
                              onSelected: (sel) => setState(() => _paymentFilter = mode),
                              backgroundColor: AppTheme.backgroundWarm,
                              selectedColor: AppTheme.espressoBrown,
                              labelStyle: GoogleFonts.epilogue(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textDark,
                              ),
                              side: BorderSide(color: isSelected ? AppTheme.espressoBrown : AppTheme.borderWarm),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                          );
                        }),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 20, color: AppTheme.borderWarm),
                        const SizedBox(width: 12),
                        Text('Status: ', style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.espressoBrown)),
                        const SizedBox(width: 4),
                        ...['ALL', 'ACTIVE', 'VOIDED'].map((status) {
                          final isSelected = _statusFilter == status;
                          Color chipColor = AppTheme.espressoBrown;
                          if (status == 'VOIDED') chipColor = Colors.red[800]!;
                          if (status == 'ACTIVE') chipColor = AppTheme.successGreenPrice;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(status),
                              selected: isSelected,
                              onSelected: (sel) => setState(() => _statusFilter = status),
                              backgroundColor: AppTheme.backgroundWarm,
                              selectedColor: chipColor,
                              labelStyle: GoogleFonts.epilogue(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textDark,
                              ),
                              side: BorderSide(color: isSelected ? chipColor : AppTheme.borderWarm),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Aggregate Financial Summary Ribbon
            _buildSummaryRibbon(
              totalCount: totalCount,
              activeCount: activeCount,
              voidedCount: voidedCount,
              netRevenue: netRevenue,
            ),

            const SizedBox(height: 16),

            if (filteredBills.isEmpty)
              _buildEmptyState(bills.isEmpty)
            else if (isDesktop)
              _buildDesktopBillTable(filteredBills, branchAsync)
            else
              _buildMobileBillList(filteredBills, branchAsync),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRibbon({
    required int totalCount,
    required int activeCount,
    required int voidedCount,
    required double netRevenue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildKpiItem('INVOICES', '$totalCount', AppTheme.espressoBrown, Icons.receipt_long_rounded),
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: AppTheme.borderWarm),
            const SizedBox(width: 16),
            _buildKpiItem('NET REVENUE', '₹${netRevenue.toStringAsFixed(0)}', AppTheme.accentCaramel, Icons.payments_rounded),
            const SizedBox(width: 16),
            Container(width: 1, height: 24, color: AppTheme.borderWarm),
            const SizedBox(width: 16),
            _buildKpiItem('ACTIVE', '$activeCount', AppTheme.successGreenPrice, Icons.check_circle_outline_rounded),
            if (voidedCount > 0) ...[
              const SizedBox(width: 16),
              Container(width: 1, height: 24, color: AppTheme.borderWarm),
              const SizedBox(width: 16),
              _buildKpiItem('VOIDED', '$voidedCount', Colors.red[800]!, Icons.cancel_outlined),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.epilogue(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.epilogue(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDateEmpty) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDateEmpty ? Icons.receipt_long_outlined : Icons.filter_alt_off_rounded,
            size: 40,
            color: AppTheme.textDark.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            isDateEmpty
                ? 'No invoices found for the selected period'
                : 'No invoices match the current filters',
            style: GoogleFonts.epilogue(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDateEmpty
                ? 'No bills generated for this date yet. Jump to recent dates:'
                : 'Try clearing search terms or selecting "ALL" status/payment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.epilogue(
              fontSize: 11.5,
              color: AppTheme.textDark.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          if (isDateEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded, size: 15),
                  label: const Text('View This Month'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.espressoBrown,
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.epilogue(fontSize: 11.5, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                  onPressed: () {
                    ref.read(analyticsDateSelectionProvider.notifier).setRange(
                          DateTime(now.year, now.month, 1),
                          now,
                        );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 15, color: AppTheme.espressoBrown),
                  label: Text('View Last 7 Days', style: GoogleFonts.epilogue(color: AppTheme.espressoBrown)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.espressoBrown),
                    textStyle: GoogleFonts.epilogue(fontSize: 11.5, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                  onPressed: () {
                    ref.read(analyticsDateSelectionProvider.notifier).setRange(
                          now.subtract(const Duration(days: 7)),
                          now,
                        );
                  },
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.clear_rounded, size: 15, color: AppTheme.espressoBrown),
              label: Text('Clear Filters & Search', style: GoogleFonts.epilogue(color: AppTheme.espressoBrown)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.espressoBrown),
                textStyle: GoogleFonts.epilogue(fontSize: 11.5, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              ),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _paymentFilter = 'ALL';
                  _statusFilter = 'ALL';
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBillTable(List<BillModel> bills, AsyncValue branchAsync) {
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('dd/MM');

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderWarm, width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.backgroundWarm),
                  headingTextStyle: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown),
                  dataTextStyle: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('INVOICE NO')),
                    DataColumn(label: Text('TIME')),
                    DataColumn(label: Text('TABLE')),
                    DataColumn(label: Text('CASHIER')),
                    DataColumn(label: Text('ITEMS')),
                    DataColumn(label: Text('PAYMENT')),
                    DataColumn(label: Text('NET TOTAL'), numeric: true),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: bills.map((bill) {
                    final itemsCount = bill.items.fold(0, (acc, item) => acc + item.qty);
                    final timeStr = '${dateFormat.format(bill.createdAt)} ${timeFormat.format(bill.createdAt)}';
                    final isReprinted = bill.printCount > 1;

                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bill.billId,
                                style: GoogleFonts.epilogue(
                                  fontWeight: FontWeight.w800,
                                  color: bill.isVoided ? Colors.red[800] : AppTheme.espressoBrown,
                                  decoration: bill.isVoided ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (bill.isVoided) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 0.8),
                                  ),
                                  child: Text(
                                    'VOIDED',
                                    style: GoogleFonts.epilogue(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.red[800]),
                                  ),
                                ),
                              ] else if (isReprinted) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${bill.printCount}x',
                                    style: GoogleFonts.epilogue(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.orange[800]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(Text(timeStr, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(bill.tableName)),
                        DataCell(Text(bill.userName.isEmpty ? 'Staff' : bill.userName)),
                        DataCell(Text('$itemsCount items')),
                        DataCell(_buildPaymentBadges(bill.payments)),
                        DataCell(
                          Text(
                            '₹${bill.total.toStringAsFixed(0)}',
                            style: GoogleFonts.epilogue(
                              fontWeight: FontWeight.w800,
                              color: bill.isVoided ? Colors.red[800] : AppTheme.textDark,
                              decoration: bill.isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.espressoBrown),
                                tooltip: 'View Bill Receipt',
                                onPressed: () => _showBillDetailsModal(bill, branchAsync),
                              ),
                              IconButton(
                                icon: const Icon(Icons.print_outlined, size: 18, color: AppTheme.accentCaramel),
                                tooltip: bill.isVoided ? 'Reprint Voided Slip' : 'Reprint Invoice Slip',
                                onPressed: branchAsync.hasValue
                                    ? () => _handleReprint(bill, branchAsync.value)
                                    : null,
                              ),
                              if (!bill.isVoided)
                                IconButton(
                                  icon: Icon(Icons.cancel_outlined, size: 18, color: Colors.red[700]),
                                  tooltip: 'Void / Cancel Invoice',
                                  onPressed: () => _showVoidBillDialog(bill),
                                )
                              else
                                IconButton(
                                  icon: Icon(Icons.block_rounded, size: 18, color: Colors.grey[400]),
                                  tooltip: 'Voided: ${bill.voidReason ?? 'No reason'}',
                                  onPressed: () => _showBillDetailsModal(bill, branchAsync),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileBillList(List<BillModel> bills, AsyncValue branchAsync) {
    final timeFormat = DateFormat('hh:mm a, dd MMM');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bill = bills[index];
        final itemsCount = bill.items.fold(0, (acc, item) => acc + item.qty);
        final isReprinted = bill.printCount > 1;

        return InkWell(
          onTap: () => _showBillDetailsModal(bill, branchAsync),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bill.isVoided ? Colors.red.withValues(alpha: 0.3) : AppTheme.borderWarm,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bill.billId,
                            style: GoogleFonts.epilogue(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: bill.isVoided ? Colors.red[800] : AppTheme.espressoBrown,
                              decoration: bill.isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (bill.isVoided) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                'VOIDED',
                                style: GoogleFonts.epilogue(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.red[800]),
                              ),
                            ),
                          ] else if (isReprinted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Printed ${bill.printCount}x',
                                style: GoogleFonts.epilogue(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${bill.tableName} • ${bill.userName} • $itemsCount items',
                        style: GoogleFonts.epilogue(fontSize: 10.5, color: AppTheme.textDark.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeFormat.format(bill.createdAt),
                        style: GoogleFonts.epilogue(fontSize: 10, color: AppTheme.textDark.withValues(alpha: 0.45)),
                      ),
                      const SizedBox(height: 6),
                      _buildPaymentBadges(bill.payments),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${bill.total.toStringAsFixed(0)}',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: bill.isVoided ? Colors.red[800] : AppTheme.textDark,
                        decoration: bill.isVoided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20, color: AppTheme.espressoBrown),
                          tooltip: bill.isVoided ? 'Reprint Void Slip' : 'Reprint Slip',
                          onPressed: branchAsync.hasValue
                              ? () => _handleReprint(bill, branchAsync.value)
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        if (!bill.isVoided) ...[
                          const SizedBox(width: 10),
                          IconButton(
                            icon: Icon(Icons.cancel_outlined, size: 20, color: Colors.red[700]),
                            tooltip: 'Void Bill',
                            onPressed: () => _showVoidBillDialog(bill),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentBadges(List<Payment> payments) {
    return Wrap(
      spacing: 4,
      children: payments.map((p) {
        Color badgeColor;
        switch (p.mode.toLowerCase()) {
          case 'cash':
            badgeColor = AppTheme.successGreenPrice;
            break;
          case 'upi':
            badgeColor = const Color(0xFF1E3A8A);
            break;
          case 'card':
            badgeColor = AppTheme.accentCaramel;
            break;
          default:
            badgeColor = AppTheme.textDark;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 0.6),
          ),
          child: Text(
            '${p.mode.toUpperCase()} ₹${p.amount.toStringAsFixed(0)}',
            style: GoogleFonts.epilogue(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
          ),
        );
      }).toList(),
    );
  }

  void _showBillDetailsModal(BillModel bill, AsyncValue branchAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.70,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            bill.billId,
                            style: GoogleFonts.epilogue(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: bill.isVoided ? Colors.red[800] : AppTheme.espressoBrown,
                              decoration: bill.isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (bill.isVoided) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 0.8),
                              ),
                              child: Text(
                                'VOIDED',
                                style: GoogleFonts.epilogue(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.red[800]),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text('${bill.tableName} • Cashier: ${bill.userName}', style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (bill.isVoided) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          Text(
                            'VOID AUDIT TRAIL',
                            style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red[800], letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Reason: ${bill.voidReason ?? 'Not specified'}', style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark)),
                      const SizedBox(height: 2),
                      Text(
                        'Voided by ${bill.voidedBy ?? 'Staff'}${bill.voidedAt != null ? ' on ${DateFormat('dd/MM/yyyy hh:mm a').format(bill.voidedAt!)}' : ''}',
                        style: GoogleFonts.epilogue(fontSize: 10.5, color: Colors.grey[700]),
                      ),
                      if (bill.tableRestored) ...[
                        const SizedBox(height: 4),
                        Text(
                          '✓ Table was restored to active floor',
                          style: GoogleFonts.epilogue(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.successGreenPrice),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              Text('ORDER ITEMS', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.espressoBrown, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ...bill.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.qty}x  ${item.name}',
                            style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '₹${(item.price * item.qty).toStringAsFixed(0)}',
                          style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 24),
              _buildReceiptDetailRow('Subtotal', '₹${bill.subtotal.toStringAsFixed(2)}'),
              if (bill.discountAmount > 0)
                _buildReceiptDetailRow('Discount', '-₹${bill.discountAmount.toStringAsFixed(2)}', color: Colors.red),
              if (bill.extraCharges > 0)
                _buildReceiptDetailRow('Extra Charges', '+₹${bill.extraCharges.toStringAsFixed(2)}'),
              const Divider(height: 16),
              _buildReceiptDetailRow(
                bill.isVoided ? 'GRAND TOTAL (VOIDED)' : 'GRAND TOTAL',
                '₹${bill.total.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 16,
                color: bill.isVoided ? Colors.red[800] : null,
              ),

              // Payment Tender Breakdown
              const Divider(height: 20),
              Text('PAYMENT TENDER BREAKDOWN', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w900, color: AppTheme.espressoBrown, letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ...bill.payments.map((p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              p.mode.toLowerCase() == 'cash'
                                  ? Icons.payments_rounded
                                  : p.mode.toLowerCase() == 'upi'
                                      ? Icons.qr_code_2_rounded
                                      : Icons.credit_card_rounded,
                              size: 16,
                              color: AppTheme.espressoBrown,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.mode.toUpperCase(),
                              style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        Text(
                          '₹${p.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),

              // Action Buttons: Reprint and Void
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(
                        bill.isVoided ? 'Reprint Void Slip' : 'Reprint Invoice Slip',
                        style: GoogleFonts.epilogue(fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.espressoBrown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: branchAsync.hasValue
                          ? () {
                              Navigator.pop(ctx);
                              _handleReprint(bill, branchAsync.value);
                            }
                          : null,
                    ),
                  ),
                  if (!bill.isVoided) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                        label: Text(
                          'Void Invoice',
                          style: GoogleFonts.epilogue(fontWeight: FontWeight.w800, color: Colors.red, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showVoidBillDialog(bill);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoidBillDialog(BillModel bill) {
    String selectedPreset = 'Wrong Table Billed';
    final reasonController = TextEditingController(text: 'Wrong Table Billed');

    final now = DateTime.now();
    final isSameDay = bill.createdAt.year == now.year &&
        bill.createdAt.month == now.month &&
        bill.createdAt.day == now.day;
    final isRecent = now.difference(bill.createdAt).inHours < 2;
    final isEligibleForRestoration = isSameDay && isRecent;

    bool restoreTable = false;
    bool isSubmitting = false;

    final presets = [
      'Wrong Table Billed',
      'Customer Dispute / Cancelled',
      'Wrong Payment Mode',
      'Duplicate Entry',
      'Cashier Error',
      'Order Returned',
      'Other Reason',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderWarm, width: 1.5),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Void Invoice',
                          style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textDark),
                        ),
                        Text(
                          bill.billId,
                          style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.espressoBrown),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundWarm.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderWarm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TABLE / ORDER', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown)),
                              Text(bill.tableName, style: GoogleFonts.epilogue(fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('AMOUNT TO REVERSE', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red[800])),
                              Text('₹${bill.total.toStringAsFixed(2)}', style: GoogleFonts.epilogue(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.red[800])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Reason for Void (Mandatory Audit Log):',
                      style: GoogleFonts.epilogue(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPreset,
                      style: GoogleFonts.epilogue(fontSize: 12, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                      ),
                      items: presets.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedPreset = val;
                            if (val != 'Other Reason') {
                              reasonController.text = val;
                            } else {
                              reasonController.clear();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      style: GoogleFonts.epilogue(fontSize: 12, color: AppTheme.textDark),
                      decoration: InputDecoration(
                        hintText: 'Enter specific reason / supervisor notes...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.borderWarm)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.espressoBrown, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isEligibleForRestoration
                            ? AppTheme.backgroundWarm.withValues(alpha: 0.35)
                            : Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEligibleForRestoration
                              ? AppTheme.borderWarm
                              : Colors.grey.withValues(alpha: 0.25),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: restoreTable,
                        onChanged: isEligibleForRestoration
                            ? (val) => setDialogState(() => restoreTable = val ?? false)
                            : null,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppTheme.espressoBrown,
                        title: Text(
                          isEligibleForRestoration
                              ? 'Restore Table & Re-open Order'
                              : 'Restore Table (Disabled for Past Bills)',
                          style: GoogleFonts.epilogue(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isEligibleForRestoration ? AppTheme.textDark : Colors.grey[600],
                          ),
                        ),
                        subtitle: Text(
                          isEligibleForRestoration
                              ? 'Optional: Re-opens ${bill.tableName} on the floor for immediate cashier correction.'
                              : 'Bill is from ${DateFormat('dd MMM, hh:mm a').format(bill.createdAt)}. Historical tables cannot be re-opened on today\'s floor.',
                          style: GoogleFonts.epilogue(
                            fontSize: 10.5,
                            color: isEligibleForRestoration ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: GoogleFonts.epilogue(fontWeight: FontWeight.w700, color: Colors.grey[700])),
                ),
                ElevatedButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(isSubmitting ? 'Voiding...' : 'Confirm Void'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[800],
                    foregroundColor: Colors.white,
                    textStyle: GoogleFonts.epilogue(fontWeight: FontWeight.w800, fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(dialogCtx);
                          final reason = reasonController.text.trim();
                          if (reason.length < 3) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please enter a valid reason (min 3 characters).'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            final user = ref.read(userModelProvider).value;
                            final voidedBy = user?.name.isNotEmpty == true
                                ? user!.name
                                : (user?.email ?? 'Supervisor');

                            final billingService = BillingService(branchId: widget.branchId);
                            await billingService.voidBill(
                              billId: bill.billId,
                              voidedBy: voidedBy,
                              voidReason: reason,
                              restoreTable: restoreTable,
                            );

                            ref.invalidate(billsForPeriodProvider(widget.branchId));
                            ref.invalidate(dashboardStatsProvider);
                            ref.invalidate(dailyAnalyticsProvider(branchId: widget.branchId));

                            if (mounted) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Invoice ${bill.billId} voided successfully.${restoreTable ? " ${bill.tableName} has been re-opened." : ""}'),
                                  backgroundColor: AppTheme.espressoBrown,
                                ),
                              );
                            }
                          } catch (e, st) {
                            debugPrint('Failed to void bill ${bill.billId}: $e\n$st');
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              String displayMsg = e.toString();
                              if (displayMsg.contains('Exception: ')) {
                                displayMsg = displayMsg.split('Exception: ').last;
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to void bill: $displayMsg'),
                                  backgroundColor: Colors.red[800],
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptDetailRow(String label, String val, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.epilogue(fontSize: fontSize, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: color)),
          Text(val, style: GoogleFonts.epilogue(fontSize: fontSize, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? AppTheme.espressoBrown)),
        ],
      ),
    );
  }

  Future<void> _handleReprint(BillModel bill, dynamic branch) async {
    try {
      final config = ref.read(printerConfigProvider);
      final printService = ref.read(printServiceProvider);
      final pdfBytes = await PdfService.generateBillPdf(bill, branch);

      if (config.address != null && config.address!.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reprinting ${bill.billId} to ${config.name}...')),
          );
        }
        await printService.printPdfAsImage(pdfBytes, config);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: bill.billId,
          format: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reprint failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
