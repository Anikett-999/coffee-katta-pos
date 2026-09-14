import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import 'dart:io';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/daily_analytics.dart';
import '../../../../domain/models/bill_model.dart';
import '../../../../services/pdf_service.dart';
import '../../../../services/excel_export_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/active_branch_provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

import 'widgets/reports_date_bar.dart';
import 'widgets/reports_overview_tab.dart';
import 'widgets/menu_engineering_tab.dart';
import 'widgets/invoice_audit_log_tab.dart';
import 'widgets/z_report_shift_tab.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const ReportsDashboardScreen({super.key, this.useShell = false});

  @override
  ConsumerState<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends ConsumerState<ReportsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getDateRangeString(Map<String, dynamic> selection) {
    final bool isRange = selection['isRange'] as bool;
    final DateTime start = selection['start'] as DateTime;
    final DateTime? end = selection['end'] as DateTime?;
    return isRange
        ? "${_dateFormat.format(start)} - ${_dateFormat.format(end ?? start)}"
        : _dateFormat.format(start);
  }

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(activeBranchIdProvider);
    if (branchId == null) {
      return const Scaffold(
        body: Center(child: Text('Please select a branch to view reports.')),
      );
    }

    final selection = ref.watch(analyticsDateSelectionProvider);
    final analyticsAsync = ref.watch(dailyAnalyticsProvider(branchId: branchId));
    final branchAsync = ref.watch(branchProvider);
    final dateRangeStr = _getDateRangeString(selection);
    final isRange = selection['isRange'] as bool;

    final Widget content = Column(
      children: [
        // Sticky Header with Presets, Date Range Badge, and Action Buttons
        ReportsDateBar(
          tabController: _tabController,
          isLoading: _isSyncing,
          onRefresh: () => _handleSync(branchId),
          onPrintZReport: () => _handlePrintZReport(analyticsAsync, branchAsync, dateRangeStr),
          onExportA4Pdf: () => _handleExportA4Pdf(analyticsAsync, branchAsync, dateRangeStr),
          onExportExcel: () => _handleExportExcel(analyticsAsync, branchAsync, dateRangeStr),
        ),

        // Tab Views
        Expanded(
          child: analyticsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.espressoBrown),
            ),
            error: (err, _) => Center(
              child: _buildErrorState(err.toString(), () => ref.invalidate(dailyAnalyticsProvider)),
            ),
            data: (analytics) {
              return TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Executive Overview & KPIs
                  ReportsOverviewTab(
                    analytics: analytics,
                    isRange: isRange,
                    onSwitchTab: (index) => _tabController.animateTo(index),
                  ),

                  // Tab 1: Menu Engineering & Item Analytics
                  MenuEngineeringTab(
                    analytics: analytics,
                  ),

                  // Tab 2: Invoice Register & Audit Log
                  InvoiceAuditLogTab(
                    branchId: branchId,
                  ),

                  // Tab 3: Day Close & Z-Report
                  ZReportShiftTab(
                    analytics: analytics,
                    dateRangeStr: dateRangeStr,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.useShell) {
      return SafeArea(child: content);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundWarm,
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
                  ],
                  const Expanded(
                    child: CoffeeKattaBrandBadge(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_rounded, color: AppTheme.warmAmber, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'REPORTS & ANALYTICS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: EditorialBackground(child: content),
    );
  }

  Future<void> _handleSync(String branchId) async {
    setState(() => _isSyncing = true);
    _showFeedbackSnackBar('Rebuilding daily aggregation from historical bills...');
    try {
      await AnalyticsService().syncHistoricalData(branchId);
      ref.invalidate(dailyAnalyticsProvider);
      ref.invalidate(billsForPeriodProvider);
      _showFeedbackSnackBar('Analytics synchronized successfully!');
    } catch (e) {
      _showFeedbackSnackBar('Sync failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handlePrintZReport(
    AsyncValue<DailyAnalytics> analyticsAsync,
    AsyncValue branchAsync,
    String dateRangeStr,
  ) async {
    if (!analyticsAsync.hasValue || !branchAsync.hasValue) {
      _showFeedbackSnackBar('Waiting for data to load...', isError: true);
      return;
    }

    try {
      _showFeedbackSnackBar('Generating 80mm Z-Report slip...');
      final config = ref.read(printerConfigProvider);
      final printService = ref.read(printServiceProvider);

      final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
        analytics: analyticsAsync.value!,
        branch: branchAsync.value!,
        dateRangeStr: dateRangeStr,
      );

      if (config.address != null && config.address!.isNotEmpty) {
        _showFeedbackSnackBar('Printing to ${config.name}...');
        final ok = await printService.printPdfAsImage(pdfBytes, config);
        if (ok) {
          _showFeedbackSnackBar('Z-Report printed successfully!');
        } else {
          _showFeedbackSnackBar('Printer offline. Opening preview...', isError: true);
          await Printing.layoutPdf(
            onLayout: (_) => pdfBytes,
            name: 'Z_Report_$dateRangeStr',
            format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
          );
        }
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'Z_Report_$dateRangeStr',
          format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
        );
      }
    } catch (e) {
      _showFeedbackSnackBar('Print failed: $e', isError: true);
    }
  }

  Future<void> _handleExportA4Pdf(
    AsyncValue<DailyAnalytics> analyticsAsync,
    AsyncValue branchAsync,
    String dateRangeStr,
  ) async {
    if (!analyticsAsync.hasValue || !branchAsync.hasValue) {
      _showFeedbackSnackBar('Waiting for data to load...', isError: true);
      return;
    }

    try {
      _showFeedbackSnackBar('Generating Executive A4 Business Report...');
      final pdfBytes = await PdfService.generateExecutiveA4Pdf(
        analytics: analyticsAsync.value!,
        branch: branchAsync.value!,
        dateRangeStr: dateRangeStr,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Executive_Report_$dateRangeStr',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      _showFeedbackSnackBar('PDF Generation failed: $e', isError: true);
    }
  }

  Future<void> _handleExportExcel(
    AsyncValue<DailyAnalytics> analyticsAsync,
    AsyncValue branchAsync,
    String dateRangeStr,
  ) async {
    if (!analyticsAsync.hasValue || !branchAsync.hasValue) {
      _showFeedbackSnackBar('Waiting for data to load...', isError: true);
      return;
    }

    try {
      _showFeedbackSnackBar('Generating Executive Excel Report (.xlsx)...');
      final branch = branchAsync.value!;

      // Fetch individual bills for itemized register sheet
      List<BillModel> bills = [];
      try {
        bills = await ref.read(billsForPeriodProvider(branch.branchId).future);
      } catch (e) {
        debugPrint('Could not fetch bills for period: $e');
      }

      final reportFileName = ExcelExportService.formatReportFileName(
        branch: branch,
        dateRangeStr: dateRangeStr,
      );

      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: analyticsAsync.value!,
        branch: branch,
        dateRangeStr: dateRangeStr,
        bills: bills,
        fileName: reportFileName,
      );

      final file = await ExcelExportService.saveAndOpenExcel(
        bytes: bytes,
        fileName: reportFileName,
      );

      if (file != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.table_view_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Executive Excel Report opened: ${file.path.split(Platform.pathSeparator).last}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1D6F42), // Microsoft Excel Emerald Green
            duration: const Duration(seconds: 8),
            action: Platform.isWindows
                ? SnackBarAction(
                    label: 'SHOW IN FOLDER',
                    textColor: Colors.white,
                    onPressed: () => ExcelExportService.revealInFolder(file.path),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      _showFeedbackSnackBar('Excel Export failed: $e', isError: true);
    }
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(
          'Failed to load analytics',
          style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.espressoBrown,
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFB91C1C) : AppTheme.espressoBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message,
          style: GoogleFonts.epilogue(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12.5),
        ),
      ),
    );
  }
}
