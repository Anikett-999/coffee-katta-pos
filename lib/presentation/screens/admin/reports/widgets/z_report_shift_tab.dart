import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../../../core/app_theme.dart';
import '../../../../../domain/models/daily_analytics.dart';
import '../../../../../services/pdf_service.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../providers/printer_provider.dart';

class ZReportShiftTab extends ConsumerStatefulWidget {
  final DailyAnalytics analytics;
  final String dateRangeStr;

  const ZReportShiftTab({
    super.key,
    required this.analytics,
    required this.dateRangeStr,
  });

  @override
  ConsumerState<ZReportShiftTab> createState() => _ZReportShiftTabState();
}

class _ZReportShiftTabState extends ConsumerState<ZReportShiftTab> {
  final _cashCountController = TextEditingController();
  final _openingFloatController = TextEditingController(text: '0');
  double _physicalCashCounted = 0.0;
  double _openingFloat = 0.0;

  @override
  void initState() {
    super.initState();
    _cashCountController.addListener(() {
      setState(() {
        _physicalCashCounted = double.tryParse(_cashCountController.text) ?? 0.0;
      });
    });
    _openingFloatController.addListener(() {
      setState(() {
        _openingFloat = double.tryParse(_openingFloatController.text) ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _cashCountController.dispose();
    _openingFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(branchProvider);
    final expectedCashSales = widget.analytics.paymentStats['cash'] ?? 0.0;
    final expectedTotalDrawerCash = _openingFloat + expectedCashSales;
    final double cashVariance = _physicalCashCounted > 0
        ? (_physicalCashCounted - expectedTotalDrawerCash)
        : 0.0;

    final double grossSales = widget.analytics.grossSales;
    final double netRevenue = widget.analytics.netRevenue;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Register Status Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.espressoBrown,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/branding/splash_logo.png',
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCaramel,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'REGISTER CLOSE (Z-REPORT)',
                                  style: GoogleFonts.epilogue(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.dateRangeStr,
                                style: GoogleFonts.epilogue(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Daily Shift & Cash Drawer Reconciliation',
                            style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verify physical drawer count against POS recorded tender totals before shift end',
                            style: GoogleFonts.epilogue(fontSize: 11, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: branchAsync.hasValue ? () => _printZReport(branchAsync.value!) : null,
                icon: const Icon(Icons.print_rounded, size: 16, color: AppTheme.espressoBrown),
                label: Text(
                  'PRINT Z-REPORT',
                  style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.espressoBrown),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildFinancialAuditCard(grossSales, netRevenue)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _buildCashDrawerReconciliationCard(expectedCashSales, expectedTotalDrawerCash, cashVariance)),
            ],
          )
        else ...[
          _buildFinancialAuditCard(grossSales, netRevenue),
          const SizedBox(height: 16),
          _buildCashDrawerReconciliationCard(expectedCashSales, expectedTotalDrawerCash, cashVariance),
        ],

        const SizedBox(height: 16),

        // Sign-off Checklist Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderWarm, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANAGER SHIFT SIGN-OFF CHECKLIST',
                style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              _buildChecklistRow(Icons.check_circle_outline_rounded, 'All open dining tables cleared and settled'),
              _buildChecklistRow(Icons.check_circle_outline_rounded, 'UPI digital settlements verified on soundbox / QR app'),
              _buildChecklistRow(Icons.check_circle_outline_rounded, 'Physical cash in drawer verified against POS expected cash'),
              _buildChecklistRow(Icons.check_circle_outline_rounded, 'Thermal Z-Report slip printed and stapled to cash deposit envelope'),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildChecklistRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.successGreenPrice),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialAuditCard(double grossSales, double netRevenue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. AUDITED FINANCIAL BALANCES',
            style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown, letterSpacing: 0.8),
          ),
          const SizedBox(height: 14),
          _buildAuditRow('Gross Food & Beverage Sales', '₹${grossSales.toStringAsFixed(2)}'),
          _buildAuditRow('Customer Discounts Given', '-₹${widget.analytics.totalDiscount.toStringAsFixed(2)}', color: Colors.red),
          _buildAuditRow('Net F&B Sales', '₹${(grossSales - widget.analytics.totalDiscount).toStringAsFixed(2)}'),
          if (widget.analytics.extraCharges > 0)
            _buildAuditRow('Packaging & Container Fees', '+₹${widget.analytics.extraCharges.toStringAsFixed(2)}'),
          const Divider(height: 20),
          _buildAuditRow('TOTAL NET REVENUE', '₹${netRevenue.toStringAsFixed(2)}', isBold: true, fontSize: 15),
          const SizedBox(height: 12),
          Text(
            'TENDER BREAKDOWN',
            style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textDark.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 8),
          _buildAuditRow('Cash Intake', '₹${(widget.analytics.paymentStats['cash'] ?? 0).toStringAsFixed(0)}'),
          _buildAuditRow('UPI Intake (PhonePe/GPay)', '₹${(widget.analytics.paymentStats['upi'] ?? 0).toStringAsFixed(0)}'),
          _buildAuditRow('Card Intake (EDC POS)', '₹${(widget.analytics.paymentStats['card'] ?? 0).toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _buildCashDrawerReconciliationCard(double expectedCashSales, double expectedTotalDrawerCash, double cashVariance) {
    Color varianceColor = Colors.grey;
    String varianceStatus = 'Enter counted drawer cash';
    if (_physicalCashCounted > 0) {
      if (cashVariance.abs() < 1) {
        varianceColor = AppTheme.successGreenPrice;
        varianceStatus = 'DRAWER BALANCED (0 VARIANCE)';
      } else if (cashVariance > 0) {
        varianceColor = Colors.blue;
        varianceStatus = 'CASH OVER: +₹${cashVariance.toStringAsFixed(0)}';
      } else {
        varianceColor = Colors.red;
        varianceStatus = 'CASH SHORTAGE: -₹${cashVariance.abs().toStringAsFixed(0)}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderWarm, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '2. PHYSICAL CASH DRAWER RECONCILIATION',
                style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: varianceColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  varianceStatus,
                  style: GoogleFonts.epilogue(fontSize: 9.5, fontWeight: FontWeight.w900, color: varianceColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Opening Cash Float (₹)', style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _openingFloatController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Physical Cash Counted (₹)', style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _cashCountController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.espressoBrown),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        hintText: '0.00',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: AppTheme.backgroundWarm.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundWarm,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildAuditRow('Expected Cash Sales in POS', '₹${expectedCashSales.toStringAsFixed(0)}'),
                _buildAuditRow('Opening Starting Float', '+₹${_openingFloat.toStringAsFixed(0)}'),
                const Divider(height: 12),
                _buildAuditRow('Total Expected Drawer Cash', '₹${expectedTotalDrawerCash.toStringAsFixed(0)}', isBold: true),
                _buildAuditRow('Actual Physical Cash Counted', '₹${_physicalCashCounted.toStringAsFixed(0)}', isBold: true),
                const Divider(height: 12),
                _buildAuditRow(
                  'Cash Variance (Over/Short)',
                  cashVariance >= 0 ? '+₹${cashVariance.toStringAsFixed(0)}' : '-₹${cashVariance.abs().toStringAsFixed(0)}',
                  isBold: true,
                  color: varianceColor,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow(String label, String val, {bool isBold = false, double fontSize = 12, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.epilogue(fontSize: fontSize, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: color)),
          Text(val, style: GoogleFonts.epilogue(fontSize: fontSize, fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, color: color ?? AppTheme.textDark)),
        ],
      ),
    );
  }

  Future<void> _printZReport(dynamic branch) async {
    try {
      final config = ref.read(printerConfigProvider);
      final printService = ref.read(printServiceProvider);
      final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
        analytics: widget.analytics,
        branch: branch,
        dateRangeStr: widget.dateRangeStr,
      );

      if (config.address != null && config.address!.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Printing Z-Report to ${config.name}...')),
          );
        }
        await printService.printPdfAsImage(pdfBytes, config);
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Z_Report_${widget.dateRangeStr}',
          format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
