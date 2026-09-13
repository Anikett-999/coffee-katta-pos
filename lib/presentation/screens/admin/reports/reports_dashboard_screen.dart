import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../../core/app_theme.dart';
import '../../../../domain/models/daily_analytics.dart';
import '../../../../domain/models/branch_model.dart';
import '../../../../services/pdf_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/active_branch_provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../providers/printer_provider.dart';
import '../../../widgets/global/editorial_background.dart';
import '../../../widgets/global/coffee_katta_brand_badge.dart';

class ReportsDashboardScreen extends ConsumerStatefulWidget {
  final bool useShell;
  const ReportsDashboardScreen({super.key, this.useShell = false});

  @override
  ConsumerState<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends ConsumerState<ReportsDashboardScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  bool _isDateConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(activeBranchIdProvider);
    if (branchId == null) {
      return const Scaffold(body: Center(child: Text('Please select a branch')));
    }

    final selection = ref.watch(analyticsDateSelectionProvider);
    final analyticsAsync = ref.watch(dailyAnalyticsProvider(branchId: branchId));
    final branchAsync = ref.watch(branchProvider);

    final mainContent = SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: anim.drive(Tween(begin: const Offset(0, 0.05), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic))),
            child: child,
          ),
        ),
        child: !_isDateConfirmed 
          ? _buildDateSelectorPage(context, selection)
          : Column(
              children: [
                _buildResultsHeader(context, selection, analyticsAsync, branchAsync),
                Expanded(
                  child: analyticsAsync.when(
                    data: (analytics) => _buildGlassyDashboard(context, analytics, selection),
                    loading: () => Center(child: CircularProgressIndicator(color: AppTheme.maroon.withOpacity(0.5))),
                    error: (err, stack) => Center(child: _buildErrorState(err.toString())),
                  ),
                ),
              ],
            ),
      ),
    );

    if (widget.useShell) {
      return EditorialBackground(child: mainContent);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                            letterSpacing: 1.0,
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
      body: EditorialBackground(child: mainContent),
    );
  }

  // --- STAGE 1: PREMIUM DATE SELECTOR PAGE ---
  Widget _buildDateSelectorPage(BuildContext context, Map<String, dynamic> selection) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return SingleChildScrollView(
      key: const ValueKey('DateSelectorPage'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Analytics Window',
            style: GoogleFonts.epilogue(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.maroon, letterSpacing: -1),
          ),
          Text(
            'Select the period you want to analyze',
            style: GoogleFonts.epilogue(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isWide ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isWide ? 1.25 : 1.1,
            children: [
              _buildQuickSelectTile('Today', Icons.today_rounded, () {
                ref.read(analyticsDateSelectionProvider.notifier).setSingleDate(DateTime.now());
              }, selection['isRange'] == false && DateUtils.isSameDay(selection['start'], DateTime.now())),
              _buildQuickSelectTile('Yesterday', Icons.history_rounded, () {
                ref.read(analyticsDateSelectionProvider.notifier).setSingleDate(DateTime.now().subtract(const Duration(days: 1)));
              }, selection['isRange'] == false && DateUtils.isSameDay(selection['start'], DateTime.now().subtract(const Duration(days: 1)))),
              _buildQuickSelectTile('Last 7 Days', Icons.date_range_rounded, () {
                final now = DateTime.now();
                ref.read(analyticsDateSelectionProvider.notifier).setRange(now.subtract(const Duration(days: 6)), now);
              }, selection['isRange'] == true),
              _buildQuickSelectTile('Custom Range', Icons.tune_rounded, () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: AppTheme.maroon, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
                    ),
                    child: child!,
                  ),
                );
                if (range != null) {
                  ref.read(analyticsDateSelectionProvider.notifier).setRange(range.start, range.end);
                }
              }, false, isSpecial: true),
            ],
          ),
          const SizedBox(height: 24),
          _buildActiveSelectionPreview(selection),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => setState(() => _isDateConfirmed = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.maroon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'CONFIRM & VIEW REPORT',
                style: GoogleFonts.epilogue(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectTile(String label, IconData icon, VoidCallback onTap, bool isSelected, {bool isSpecial = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.maroon : (isSpecial ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppTheme.maroon : Colors.white.withOpacity(0.5), width: 2),
          boxShadow: [
            if (isSelected) BoxShadow(color: AppTheme.maroon.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.white : AppTheme.maroon),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.epilogue(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppTheme.maroon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSelectionPreview(Map<String, dynamic> selection) {
    final start = selection['start'] as DateTime;
    final end = selection['end'] as DateTime?;
    final isRange = selection['isRange'] as bool;
    final text = isRange ? "${_dateFormat.format(start)} - ${_dateFormat.format(end ?? start)}" : _dateFormat.format(start);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SELECTED PERIOD', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[600], letterSpacing: 1)),
              Text(text, style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.maroon)),
            ],
          ),
        ],
      ),
    );
  }

  // --- STAGE 2: ANALYTICS VIEW ---
  Widget _buildResultsHeader(
    BuildContext context, 
    Map<String, dynamic> selection,
    AsyncValue<DailyAnalytics> analyticsAsync,
    AsyncValue<BranchModel> branchAsync,
  ) {
    final isRange = selection['isRange'] as bool;
    final start = selection['start'] as DateTime;
    final end = selection['end'] as DateTime?;
    final dateStr = isRange ? "${_dateFormat.format(start)} - ${_dateFormat.format(end ?? start)}" : _dateFormat.format(start);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => setState(() => _isDateConfirmed = false),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ANALYTICS',
                    style: GoogleFonts.epilogue(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey[700], letterSpacing: 1.5),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.maroon),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.sync_rounded,
            onTap: () async {
              final branchId = ref.read(activeBranchIdProvider);
              if (branchId != null) {
                _showGlassySnackBar('Refreshing sales data...');
                await AnalyticsService().syncHistoricalData(branchId);
                ref.invalidate(dailyAnalyticsProvider);
              }
            },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.local_printshop_rounded,
            isPrimary: true,
            onTap: (analyticsAsync.hasValue && branchAsync.hasValue) 
              ? () async {
                  try {
                    final config = ref.read(printerConfigProvider);
                    final printService = ref.read(printServiceProvider);
                    
                    _showGlassySnackBar('Generating Business Report...');
                    final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
                      analytics: analyticsAsync.value!,
                      branch: branchAsync.value!,
                      dateRangeStr: dateStr,
                    );
                    
                    if (config.address != null && config.address!.isNotEmpty) {
                      _showGlassySnackBar('Printing to ${config.name}...');
                      final success = await printService.printPdfAsImage(pdfBytes, config);
                      if (success) {
                        _showGlassySnackBar('Report printed & cut successfully!');
                      } else {
                        _showGlassySnackBar('Thermal print failed. Opening preview...', isError: true);
                        await Printing.layoutPdf(
                          onLayout: (format) => pdfBytes, 
                          name: 'Report_$dateStr',
                          format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
                        );
                      }
                    } else {
                      _showGlassySnackBar('No printer configured. Opening preview...');
                      await Printing.layoutPdf(
                        onLayout: (format) => pdfBytes, 
                        name: 'Report_$dateStr',
                        format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
                      );
                    }
                  } catch (e) {
                    _showGlassySnackBar('Print failed: $e', isError: true);
                  }
                }
              : null,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.ios_share_rounded,
            onTap: (analyticsAsync.hasValue && branchAsync.hasValue) 
              ? () async {
                  try {
                    _showGlassySnackBar('Opening PDF Preview...');
                    final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
                      analytics: analyticsAsync.value!,
                      branch: branchAsync.value!,
                      dateRangeStr: dateStr,
                    );
                    await Printing.layoutPdf(
                      onLayout: (format) => pdfBytes, 
                      name: 'Report_$dateStr',
                      format: PdfPageFormat(72 * PdfPageFormat.mm, double.infinity),
                    );
                  } catch (e) {
                    _showGlassySnackBar('Expert failed: $e', isError: true);
                  }
                }
              : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, VoidCallback? onTap, bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.maroon : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Icon(icon, color: isPrimary ? Colors.white : AppTheme.maroon, size: 20),
      ),
    );
  }

  Widget _buildGlassyDashboard(BuildContext context, DailyAnalytics analytics, Map<String, dynamic> selection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 900;
        final bool isTablet = constraints.maxWidth > 600;
        
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildMetricsGrid(analytics, isDesktop, isTablet),
            const SizedBox(height: 24),
            _buildSectionHeader('Live Performance'),
            const SizedBox(height: 12),
            _buildHourlyAnalysis(analytics),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildTopItemsGlass(analytics)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildPaymentDistribution(analytics)),
                ],
              )
            else ...[
              _buildTopItemsGlass(analytics),
              const SizedBox(height: 16),
              _buildPaymentDistribution(analytics),
            ],
            const SizedBox(height: 24),
            _buildItemPerformanceAnalysis(analytics),
            const SizedBox(height: 24),
            _buildInsightsGlass(analytics),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildItemPerformanceAnalysis(DailyAnalytics analytics) {
    if (analytics.itemStats.isEmpty) return const SizedBox.shrink();

    final mostSold = analytics.itemStats.values.toList()
      ..sort((a, b) {
        int cmp = b.qty.compareTo(a.qty);
        if (cmp == 0) return b.revenue.compareTo(a.revenue);
        return cmp;
      });

    final leastPerformed = analytics.itemStats.values.toList()
      ..sort((a, b) {
        int cmp = a.qty.compareTo(b.qty);
        if (cmp == 0) return a.revenue.compareTo(b.revenue);
        return cmp;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Item Analysis'),
        const SizedBox(height: 12),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Most Sold Items', style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800)),
                  _buildBadge('TOP VOLUME'),
                ],
              ),
              const SizedBox(height: 16),
              ...mostSold.take(5).map((item) => _buildEnhancedItemRow(item, isPositive: true)),
              
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Divider(height: 1, thickness: 0.5),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Least Performed Items', style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey[800])),
                  _buildBadge('LOW VOLUME'),
                ],
              ),
              const SizedBox(height: 16),
              ...leastPerformed.take(5).map((item) => _buildEnhancedItemRow(item, isPositive: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedItemRow(ItemStat item, {required bool isPositive}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isPositive ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 16,
              color: isPositive ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.toUpperCase(), 
                  style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
                Text(
                  '${item.qty} Sold', 
                  style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '₹${item.revenue.toStringAsFixed(0)}', 
            style: GoogleFonts.epilogue(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.maroon)
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(DailyAnalytics analytics, bool isDesktop, bool isTablet) {
    final aov = analytics.totalBills > 0 ? analytics.totalSales / analytics.totalBills : 0.0;
    int crossCount = isDesktop ? 4 : (isTablet ? 3 : 2);
    
    return GridView.count(
      crossAxisCount: crossCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: isTablet ? 1.5 : 1.3, // Adjusted to prevent overflow
      children: [
        _buildMetricCard('GROSS SALES', '₹${analytics.totalSales.toStringAsFixed(0)}', Icons.account_balance_wallet_rounded, Colors.green),
        _buildMetricCard('ORDER COUNT', '${analytics.totalBills}', Icons.receipt_rounded, Colors.blue),
        _buildMetricCard('AVG TICKET', '₹${aov.toStringAsFixed(0)}', Icons.bolt_rounded, Colors.orange),
        _buildMetricCard('DISCOUNTS', '₹${analytics.totalDiscount.toStringAsFixed(0)}', Icons.local_offer_rounded, Colors.red),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accent) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 12, color: accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: GoogleFonts.epilogue(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value, 
              style: GoogleFonts.epilogue(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyAnalysis(DailyAnalytics analytics) {
    final stats = analytics.hourlyStats.map((k, v) => MapEntry(int.parse(k), v.sales));
    
    return GlassContainer(
      height: 240,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales by Frequency', style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800)),
              _buildBadge('HOURLY'),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: stats.isEmpty ? Center(child: Text('No data', style: GoogleFonts.epilogue(color: Colors.grey))) : _buildBarChart(stats),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<int, double> stats) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (stats.values.fold(0.0, (p, c) => c > p ? c : p) * 1.2).clamp(100, double.infinity),
        barGroups: List.generate(24, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: stats[i] ?? 0,
                color: AppTheme.maroon,
                width: 4,
                borderRadius: BorderRadius.circular(2),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1000, color: AppTheme.maroon.withOpacity(0.03)),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) => v % 6 == 0 ? Text('${v.toInt()}h', style: GoogleFonts.epilogue(fontSize: 9, color: Colors.grey)) : const SizedBox(),
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildTopItemsGlass(DailyAnalytics analytics) {
    final sorted = analytics.itemStats.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Top Sellers', style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800)),
              _buildBadge('PERFORMANCE'),
            ],
          ),
          const SizedBox(height: 16),
          if (sorted.isEmpty) Text('No sales', style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey))
          else ...sorted.take(4).map((e) => _buildItemRow(e)),
        ],
      ),
    );
  }

  Widget _buildItemRow(MapEntry<String, dynamic> e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.value.name, style: GoogleFonts.epilogue(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${e.value.qty} items', style: GoogleFonts.epilogue(fontSize: 9, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('₹${e.value.revenue.toStringAsFixed(0)}', style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.maroon)),
        ],
      ),
    );
  }

  Widget _buildPaymentDistribution(DailyAnalytics analytics) {
    double total = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payments', style: GoogleFonts.epilogue(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: total == 0 ? Center(child: Text('N/A', style: GoogleFonts.epilogue(fontSize: 10))) : PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 20,
                sections: [
                  PieChartSectionData(value: analytics.paymentStats['cash'] ?? 0, color: Colors.green.withOpacity(0.6), radius: 12, showTitle: false),
                  PieChartSectionData(value: analytics.paymentStats['upi'] ?? 0, color: Colors.blue.withOpacity(0.6), radius: 12, showTitle: false),
                  PieChartSectionData(value: analytics.paymentStats['card'] ?? 0, color: Colors.purple.withOpacity(0.6), radius: 12, showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildPaymentLedger('Cash', analytics.paymentStats['cash'] ?? 0, Colors.green),
          _buildPaymentLedger('UPI', analytics.paymentStats['upi'] ?? 0, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildInsightsGlass(DailyAnalytics analytics) {
    final sortedItems = analytics.itemStats.entries.toList()..sort((a,b) => b.value.qty.compareTo(a.value.qty));
    final best = sortedItems.isNotEmpty ? sortedItems.first.value.name : 'N/A';
    final sortedHours = analytics.hourlyStats.entries.toList()..sort((a,b) => b.value.sales.compareTo(a.value.sales));
    final peak = sortedHours.isNotEmpty ? '${sortedHours.first.key}:00' : 'N/A';

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Smart Insights', style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _buildInsightRow(Icons.auto_awesome_rounded, 'Bestselling Item', best),
          const Divider(height: 24, thickness: 0.5),
          _buildInsightRow(Icons.access_time_filled_rounded, 'Peak Traffic', peak),
          const Divider(height: 24, thickness: 0.5),
          _buildInsightRow(Icons.stars_rounded, 'Business Pulse', 'EXCELLENT'),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.maroon),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 12),
        Text(val, style: GoogleFonts.epilogue(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.maroon), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.maroon.withOpacity(0.4)));
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppTheme.maroon.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: GoogleFonts.epilogue(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.maroon)),
    );
  }

  Widget _buildPaymentLedger(String label, double val, Color c) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.epilogue(fontSize: 9, color: Colors.grey[700])),
        const Spacer(),
        Text('₹${val.toStringAsFixed(0)}', style: GoogleFonts.epilogue(fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }

  void _showGlassySnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(color: (isError ? Colors.red : AppTheme.maroon).withOpacity(0.8), borderRadius: BorderRadius.circular(16)),
              child: Text(message, style: GoogleFonts.epilogue(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.maroon.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text('Failed to load insights', style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(error, textAlign: TextAlign.center, style: GoogleFonts.epilogue(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({super.key, required this.child, this.height, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }
}
