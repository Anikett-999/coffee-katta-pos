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

class InvoiceAuditLogTab extends ConsumerStatefulWidget {
  final String branchId;

  const InvoiceAuditLogTab({
    super.key,
    required this.branchId,
  });

  @override
  ConsumerState<InvoiceAuditLogTab> createState() => _InvoiceAuditLogTabState();
}

class _InvoiceAuditLogTabState extends ConsumerState<InvoiceAuditLogTab> {
  String _searchQuery = '';
  String _paymentFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
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
        final filteredBills = bills.where((b) {
          final matchesSearch = b.billId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              b.tableName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              b.userName.toLowerCase().contains(_searchQuery.toLowerCase());

          if (!matchesSearch) return false;

          if (_paymentFilter != 'ALL') {
            final hasMode = b.payments.any((p) => p.mode.toLowerCase() == _paymentFilter.toLowerCase());
            if (!hasMode) return false;
          }
          return true;
        }).toList();

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
                      hintText: 'Search by Invoice No (INV-...), Table, or Cashier...',
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
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'CASH', 'UPI', 'CARD'].map((mode) {
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
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (filteredBills.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textDark.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'No invoices found for the selected period',
                      style: GoogleFonts.epilogue(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
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

  Widget _buildDesktopBillTable(List<BillModel> bills, AsyncValue branchAsync) {
    final timeFormat = DateFormat('hh:mm a');
    final dateFormat = DateFormat('dd/MM');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
                        style: GoogleFonts.epilogue(fontWeight: FontWeight.w800, color: AppTheme.espressoBrown),
                      ),
                      if (isReprinted) ...[
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
                    style: GoogleFonts.epilogue(fontWeight: FontWeight.w800, color: AppTheme.textDark),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.espressoBrown),
                        tooltip: 'View Bill Receipt',
                        onPressed: () => _showBillDetailsModal(bill),
                      ),
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 18, color: AppTheme.accentCaramel),
                        tooltip: 'Reprint Invoice Slip',
                        onPressed: branchAsync.hasValue
                            ? () => _handleReprint(bill, branchAsync.value)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
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
          onTap: () => _showBillDetailsModal(bill),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderWarm, width: 1),
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
                              color: AppTheme.espressoBrown,
                            ),
                          ),
                          if (isReprinted) ...[
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
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20, color: AppTheme.espressoBrown),
                      onPressed: branchAsync.hasValue
                          ? () => _handleReprint(bill, branchAsync.value)
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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

  void _showBillDetailsModal(BillModel bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
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
                      Text(bill.billId, style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.espressoBrown)),
                      Text('${bill.tableName} • Cashier: ${bill.userName}', style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
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
              _buildReceiptDetailRow('GRAND TOTAL', '₹${bill.total.toStringAsFixed(2)}', isBold: true, fontSize: 16),
            ],
          ),
        ),
      ),
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
