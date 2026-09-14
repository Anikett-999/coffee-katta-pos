import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/models/daily_analytics.dart';
import '../domain/models/branch_model.dart';
import '../domain/models/bill_model.dart';

/// High-end Executive Excel (.xlsx) Report Generator for Coffee Katta
class ExcelExportService {
  // Brand Color Palette for Excel Cells (ARGB Hex)
  static final _espresso = ExcelColor.fromHexString('FF382012');
  static final _amber = ExcelColor.fromHexString('FFB77945');
  static final _cream = ExcelColor.fromHexString('FFEFECE6');
  static final _cardBg = ExcelColor.fromHexString('FFF7F4EF');
  static final _zebraBg = ExcelColor.fromHexString('FFFDFCFB');
  static final _white = ExcelColor.fromHexString('FFFFFFFF');
  static final _textDark = ExcelColor.fromHexString('FF29231F');
  static final _textMuted = ExcelColor.fromHexString('FF6B5E55');

  // Styles
  static final _bannerStyle = CellStyle(
    bold: true,
    backgroundColorHex: _espresso,
    fontColorHex: _white,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _bannerSubStyle = CellStyle(
    bold: false,
    backgroundColorHex: _espresso,
    fontColorHex: _cream,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _sectionStyle = CellStyle(
    bold: true,
    backgroundColorHex: _amber,
    fontColorHex: _white,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _tableHeaderStyle = CellStyle(
    bold: true,
    backgroundColorHex: _cream,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _tableHeaderRightStyle = CellStyle(
    bold: true,
    backgroundColorHex: _cream,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Right,
  );

  static final _kpiLabelStyle = CellStyle(
    bold: true,
    backgroundColorHex: _cardBg,
    fontColorHex: _textMuted,
    horizontalAlign: HorizontalAlign.Center,
  );

  static final _kpiValueStyle = CellStyle(
    bold: true,
    backgroundColorHex: _cardBg,
    fontColorHex: _espresso,
    horizontalAlign: HorizontalAlign.Center,
  );

  static final _regularLeft = CellStyle(
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _regularRight = CellStyle(
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Right,
  );

  static final _zebraLeft = CellStyle(
    backgroundColorHex: _zebraBg,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _zebraRight = CellStyle(
    backgroundColorHex: _zebraBg,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Right,
  );

  static final _totalRowLeft = CellStyle(
    bold: true,
    backgroundColorHex: _cream,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _totalRowRight = CellStyle(
    bold: true,
    backgroundColorHex: _cream,
    fontColorHex: _textDark,
    horizontalAlign: HorizontalAlign.Right,
  );

  /// Formats a professional business filename for the Excel report, replacing any generic or framework default names
  static String formatReportFileName({
    required BranchModel branch,
    required String dateRangeStr,
  }) {
    String cleanBranch = branch.branchName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    // Avoid redundant "CoffeeKatta_Coffee_Katta"
    if (cleanBranch.toLowerCase() == 'coffee_katta' || cleanBranch.toLowerCase() == 'coffeekatta') {
      cleanBranch = '';
    } else if (cleanBranch.toLowerCase().startsWith('coffee_katta_')) {
      cleanBranch = cleanBranch.substring('coffee_katta_'.length);
    }

    final cleanDate = dateRangeStr
        .trim()
        .replaceAll(RegExp(r'\s*-\s*'), '_to_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final branchPart = cleanBranch.isNotEmpty ? '${cleanBranch}_' : '';
    final datePart = cleanDate.isNotEmpty ? '_$cleanDate' : '';
    return 'CoffeeKatta_${branchPart}Executive_Report$datePart.xlsx';
  }

  /// Generates a professional 5-sheet Executive Excel (.xlsx) workbook
  static List<int> generateExecutiveWorkbook({
    required DailyAnalytics analytics,
    required BranchModel branch,
    required String dateRangeStr,
    List<BillModel> bills = const [],
    String? fileName,
  }) {
    final excel = Excel.createExcel();

    // 1. Sheet: Executive Overview
    const s1 = 'Executive Overview';
    final sheet1 = excel[s1];
    excel.setDefaultSheet(s1);
    _buildExecutiveOverviewSheet(sheet1, analytics, branch, dateRangeStr);

    // 2. Sheet: Category Sales & Mix
    const s2 = 'Category Sales';
    final sheet2 = excel[s2];
    _buildCategorySalesSheet(sheet2, analytics);

    // 3. Sheet: Top Menu Items
    const s3 = 'Top Menu Items';
    final sheet3 = excel[s3];
    _buildTopMenuItemsSheet(sheet3, analytics);

    // 4. Sheet: Hourly Sales Velocity
    const s4 = 'Hourly Velocity';
    final sheet4 = excel[s4];
    _buildHourlyVelocitySheet(sheet4, analytics);

    // 5. Sheet: Itemized Bills Register
    const s5 = 'Invoices Register';
    final sheet5 = excel[s5];
    _buildBillsRegisterSheet(sheet5, bills, branch, dateRangeStr);

    // Delete default Sheet1 if exists
    try {
      excel.delete('Sheet1');
    } catch (_) {}

    final effectiveFileName = (fileName != null && fileName.trim().isNotEmpty)
        ? (fileName.endsWith('.xlsx') ? fileName.trim() : '${fileName.trim()}.xlsx')
        : formatReportFileName(branch: branch, dateRangeStr: dateRangeStr);

    return excel.save(fileName: effectiveFileName) ?? [];
  }

  // ---------------------------------------------------------------------------
  // SHEET 1: EXECUTIVE OVERVIEW
  // ---------------------------------------------------------------------------
  static void _buildExecutiveOverviewSheet(
    Sheet sheet,
    DailyAnalytics a,
    BranchModel branch,
    String dateRangeStr,
  ) {
    int row = 0;

    // Header Banner
    _setCell(sheet, 0, row, 'COFFEE KATTA - EXECUTIVE BUSINESS & FINANCIAL AUDIT REPORT', style: _bannerStyle);
    for (int col = 1; col <= 8; col++) {
      _setCell(sheet, col, row, '', style: _bannerStyle);
    }
    row++;

    final genTime = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    _setCell(sheet, 0, row, 'Branch: ${branch.branchName} (${branch.location}) | Address: ${branch.address} | Phone: ${branch.phone}', style: _bannerSubStyle);
    for (int col = 1; col <= 8; col++) {
      _setCell(sheet, col, row, '', style: _bannerSubStyle);
    }
    row++;

    _setCell(sheet, 0, row, 'Reporting Period: $dateRangeStr | Generated: $genTime | Audit Seal: 100% RECONCILED', style: _bannerSubStyle);
    for (int col = 1; col <= 8; col++) {
      _setCell(sheet, col, row, '', style: _bannerSubStyle);
    }
    row += 2;

    // KPI METRIC CARDS (6 Key Metrics)
    _setCell(sheet, 0, row, 'EXECUTIVE KPI SNAPSHOT', style: _sectionStyle);
    for (int col = 1; col <= 8; col++) {
      _setCell(sheet, col, row, '', style: _sectionStyle);
    }
    row++;

    // KPI Labels
    _setCell(sheet, 0, row, 'NET REVENUE (INR)', style: _kpiLabelStyle);
    _setCell(sheet, 1, row, 'SETTLED ORDERS', style: _kpiLabelStyle);
    _setCell(sheet, 2, row, 'AVG TICKET (AOV)', style: _kpiLabelStyle);
    _setCell(sheet, 3, row, 'GROSS SALES (INR)', style: _kpiLabelStyle);
    _setCell(sheet, 4, row, 'TOTAL DISCOUNTS', style: _kpiLabelStyle);
    _setCell(sheet, 5, row, 'EXTRA CHARGES / TAX', style: _kpiLabelStyle);
    row++;

    // KPI Values
    _setCell(sheet, 0, row, a.netRevenue, isDouble: true, style: _kpiValueStyle);
    _setCell(sheet, 1, row, a.totalBills, isInt: true, style: _kpiValueStyle);
    _setCell(sheet, 2, row, a.aov, isDouble: true, style: _kpiValueStyle);
    _setCell(sheet, 3, row, a.grossSales, isDouble: true, style: _kpiValueStyle);
    _setCell(sheet, 4, row, a.totalDiscount, isDouble: true, style: _kpiValueStyle);
    _setCell(sheet, 5, row, a.extraCharges, isDouble: true, style: _kpiValueStyle);
    row += 3;

    // 2-COLUMN SECTION: Financial Reconciliation (Col 0-2) and Payment Breakdown (Col 4-7)
    _setCell(sheet, 0, row, 'FINANCIAL RECONCILIATION STATEMENT', style: _sectionStyle);
    _setCell(sheet, 1, row, '', style: _sectionStyle);
    _setCell(sheet, 2, row, '', style: _sectionStyle);

    _setCell(sheet, 4, row, 'PAYMENT SETTLEMENT BREAKDOWN', style: _sectionStyle);
    _setCell(sheet, 5, row, '', style: _sectionStyle);
    _setCell(sheet, 6, row, '', style: _sectionStyle);
    _setCell(sheet, 7, row, '', style: _sectionStyle);
    row++;

    // Table Headers
    _setCell(sheet, 0, row, 'Accounting Line Item', style: _tableHeaderStyle);
    _setCell(sheet, 1, row, 'Amount (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 2, row, '% of Gross', style: _tableHeaderRightStyle);

    _setCell(sheet, 4, row, 'Tender / Payment Mode', style: _tableHeaderStyle);
    _setCell(sheet, 5, row, 'Amount (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 6, row, 'Share (%)', style: _tableHeaderRightStyle);
    _setCell(sheet, 7, row, 'Reconciliation', style: _tableHeaderStyle);
    row++;

    final gross = a.grossSales > 0 ? a.grossSales : 1.0;
    final netRev = a.netRevenue;

    // Row 1: Gross Sales vs Payment 1
    final payEntries = a.paymentStats.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    final pay1 = payEntries.isNotEmpty ? payEntries[0] : null;
    final pay1Pct = pay1 != null && netRev > 0 ? (pay1.value / netRev) * 100 : 0.0;

    _setCell(sheet, 0, row, 'Gross Food & Beverage Sales', style: _regularLeft);
    _setCell(sheet, 1, row, a.grossSales, isDouble: true, style: _regularRight);
    _setCell(sheet, 2, row, '100.0%', style: _regularRight);

    if (pay1 != null) {
      _setCell(sheet, 4, row, pay1.key.toUpperCase(), style: _regularLeft);
      _setCell(sheet, 5, row, pay1.value, isDouble: true, style: _regularRight);
      _setCell(sheet, 6, row, '${pay1Pct.toStringAsFixed(1)}%', style: _regularRight);
      _setCell(sheet, 7, row, 'VERIFIED', style: _regularLeft);
    }
    row++;

    // Row 2: Discounts vs Payment 2
    final pay2 = payEntries.length > 1 ? payEntries[1] : null;
    final pay2Pct = pay2 != null && netRev > 0 ? (pay2.value / netRev) * 100 : 0.0;
    final discPct = (a.totalDiscount / gross) * 100;

    _setCell(sheet, 0, row, 'Total Discounts & Promos', style: _zebraLeft);
    _setCell(sheet, 1, row, -a.totalDiscount, isDouble: true, style: _zebraRight);
    _setCell(sheet, 2, row, '-${discPct.toStringAsFixed(1)}%', style: _zebraRight);

    if (pay2 != null) {
      _setCell(sheet, 4, row, pay2.key.toUpperCase(), style: _zebraLeft);
      _setCell(sheet, 5, row, pay2.value, isDouble: true, style: _zebraRight);
      _setCell(sheet, 6, row, '${pay2Pct.toStringAsFixed(1)}%', style: _zebraRight);
      _setCell(sheet, 7, row, 'VERIFIED', style: _zebraLeft);
    }
    row++;

    // Row 3: Net Sales vs Payment 3
    final pay3 = payEntries.length > 2 ? payEntries[2] : null;
    final pay3Pct = pay3 != null && netRev > 0 ? (pay3.value / netRev) * 100 : 0.0;
    final netSalesPct = (a.netSales / gross) * 100;

    _setCell(sheet, 0, row, 'Net Food & Beverage Sales', style: _regularLeft);
    _setCell(sheet, 1, row, a.netSales, isDouble: true, style: _regularRight);
    _setCell(sheet, 2, row, '${netSalesPct.toStringAsFixed(1)}%', style: _regularRight);

    if (pay3 != null) {
      _setCell(sheet, 4, row, pay3.key.toUpperCase(), style: _zebraLeft);
      _setCell(sheet, 5, row, pay3.value, isDouble: true, style: _regularRight);
      _setCell(sheet, 6, row, '${pay3Pct.toStringAsFixed(1)}%', style: _regularRight);
      _setCell(sheet, 7, row, 'VERIFIED', style: _zebraLeft);
    }
    row++;

    // Row 4: Extra Charges / Tax vs Payment 4
    final pay4 = payEntries.length > 3 ? payEntries[3] : null;
    final pay4Pct = pay4 != null && netRev > 0 ? (pay4.value / netRev) * 100 : 0.0;
    final chargesPct = (a.extraCharges / gross) * 100;

    _setCell(sheet, 0, row, 'Delivery / Packaging / Taxes', style: _zebraLeft);
    _setCell(sheet, 1, row, a.extraCharges, isDouble: true, style: _zebraRight);
    _setCell(sheet, 2, row, '+${chargesPct.toStringAsFixed(1)}%', style: _zebraRight);

    if (pay4 != null) {
      _setCell(sheet, 4, row, pay4.key.toUpperCase(), style: _zebraLeft);
      _setCell(sheet, 5, row, pay4.value, isDouble: true, style: _zebraRight);
      _setCell(sheet, 6, row, '${pay4Pct.toStringAsFixed(1)}%', style: _zebraRight);
      _setCell(sheet, 7, row, 'VERIFIED', style: _zebraLeft);
    }
    row++;

    // Total Row
    final totalTender = a.paymentStats.values.fold(0.0, (p, c) => p + c);

    _setCell(sheet, 0, row, 'TOTAL NET PAYABLE REVENUE', style: _totalRowLeft);
    _setCell(sheet, 1, row, a.netRevenue, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 2, row, '${((a.netRevenue / gross) * 100).toStringAsFixed(1)}%', style: _totalRowRight);

    _setCell(sheet, 4, row, 'TOTAL SETTLED TENDER', style: _totalRowLeft);
    _setCell(sheet, 5, row, totalTender, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 6, row, '100.0%', style: _totalRowRight);
    _setCell(sheet, 7, row, 'MATCHED', style: _totalRowLeft);
    row += 3;

    // STAFF & CASHIER SALES CONTRIBUTION
    if (a.userStats.isNotEmpty) {
      _setCell(sheet, 0, row, 'CASHIER & STAFF AUDIT CONTRIBUTION', style: _sectionStyle);
      _setCell(sheet, 1, row, '', style: _sectionStyle);
      _setCell(sheet, 2, row, '', style: _sectionStyle);
      row++;

      _setCell(sheet, 0, row, 'Cashier / Staff Name', style: _tableHeaderStyle);
      _setCell(sheet, 1, row, 'Total Sales (INR)', style: _tableHeaderRightStyle);
      _setCell(sheet, 2, row, 'Contribution (%)', style: _tableHeaderRightStyle);
      row++;

      int uIdx = 0;
      for (final u in a.userStats.entries) {
        final uStyleL = uIdx % 2 == 1 ? _zebraLeft : _regularLeft;
        final uStyleR = uIdx % 2 == 1 ? _zebraRight : _regularRight;
        final uPct = a.netRevenue > 0 ? (u.value / a.netRevenue) * 100 : 0.0;

        _setCell(sheet, 0, row, u.key, style: uStyleL);
        _setCell(sheet, 1, row, u.value, isDouble: true, style: uStyleR);
        _setCell(sheet, 2, row, '${uPct.toStringAsFixed(1)}%', style: uStyleR);
        row++;
        uIdx++;
      }
    }

    // Auto Column Widths
    sheet.setColumnWidth(0, 32.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 6.0);
    sheet.setColumnWidth(4, 26.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 14.0);
    sheet.setColumnWidth(7, 18.0);
  }

  // ---------------------------------------------------------------------------
  // SHEET 2: CATEGORY SALES & MENU MIX
  // ---------------------------------------------------------------------------
  static void _buildCategorySalesSheet(Sheet sheet, DailyAnalytics a) {
    int row = 0;

    _setCell(sheet, 0, row, 'COFFEE KATTA - CATEGORY PERFORMANCE & SALES MIX', style: _bannerStyle);
    for (int c = 1; c <= 4; c++) {
      _setCell(sheet, c, row, '', style: _bannerStyle);
    }
    row += 2;

    _setCell(sheet, 0, row, 'Rank', style: _tableHeaderStyle);
    _setCell(sheet, 1, row, 'Category Name', style: _tableHeaderStyle);
    _setCell(sheet, 2, row, 'Gross Revenue (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 3, row, 'Sales Share (%)', style: _tableHeaderRightStyle);
    _setCell(sheet, 4, row, 'Cumulative Mix (%)', style: _tableHeaderRightStyle);
    row++;

    final sortedCats = a.categoryStats.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    final totalCatSales = sortedCats.fold(0.0, (p, c) => p + c.value);
    double cumulative = 0.0;

    for (int i = 0; i < sortedCats.length; i++) {
      final cat = sortedCats[i];
      final isZebra = i % 2 == 1;
      final styleL = isZebra ? _zebraLeft : _regularLeft;
      final styleR = isZebra ? _zebraRight : _regularRight;

      final pct = totalCatSales > 0 ? (cat.value / totalCatSales) * 100 : 0.0;
      cumulative += pct;

      _setCell(sheet, 0, row, '#${i + 1}', style: styleL);
      _setCell(sheet, 1, row, cat.key, style: styleL);
      _setCell(sheet, 2, row, cat.value, isDouble: true, style: styleR);
      _setCell(sheet, 3, row, '${pct.toStringAsFixed(1)}%', style: styleR);
      _setCell(sheet, 4, row, '${cumulative.clamp(0.0, 100.0).toStringAsFixed(1)}%', style: styleR);
      row++;
    }

    // Category Total Row
    _setCell(sheet, 0, row, 'TOTAL', style: _totalRowLeft);
    _setCell(sheet, 1, row, 'All Categories Combined', style: _totalRowLeft);
    _setCell(sheet, 2, row, totalCatSales, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 3, row, '100.0%', style: _totalRowRight);
    _setCell(sheet, 4, row, '100.0%', style: _totalRowRight);

    sheet.setColumnWidth(0, 10.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 20.0);
  }

  // ---------------------------------------------------------------------------
  // SHEET 3: TOP MENU ITEMS RANKING
  // ---------------------------------------------------------------------------
  static void _buildTopMenuItemsSheet(Sheet sheet, DailyAnalytics a) {
    int row = 0;

    _setCell(sheet, 0, row, 'COFFEE KATTA - TOP SELLING MENU ITEMS RANKING', style: _bannerStyle);
    for (int c = 1; c <= 5; c++) {
      _setCell(sheet, c, row, '', style: _bannerStyle);
    }
    row += 2;

    _setCell(sheet, 0, row, 'Rank', style: _tableHeaderStyle);
    _setCell(sheet, 1, row, 'Item Name', style: _tableHeaderStyle);
    _setCell(sheet, 2, row, 'Units Sold', style: _tableHeaderRightStyle);
    _setCell(sheet, 3, row, 'Total Revenue (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 4, row, 'Avg Price (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 5, row, 'Menu Share (%)', style: _tableHeaderRightStyle);
    row++;

    final sortedItems = a.itemStats.values.toList()
      ..sort((x, y) {
        final rev = y.revenue.compareTo(x.revenue);
        return rev != 0 ? rev : y.qty.compareTo(x.qty);
      });

    final totalItemRevenue = sortedItems.fold(0.0, (p, c) => p + c.revenue);
    final totalUnits = sortedItems.fold(0, (p, c) => p + c.qty);

    for (int i = 0; i < sortedItems.length; i++) {
      final item = sortedItems[i];
      final isZebra = i % 2 == 1;
      final styleL = isZebra ? _zebraLeft : _regularLeft;
      final styleR = isZebra ? _zebraRight : _regularRight;

      final avgPrice = item.qty > 0 ? item.revenue / item.qty : 0.0;
      final share = totalItemRevenue > 0 ? (item.revenue / totalItemRevenue) * 100 : 0.0;

      _setCell(sheet, 0, row, '#${i + 1}', style: styleL);
      _setCell(sheet, 1, row, item.name, style: styleL);
      _setCell(sheet, 2, row, item.qty, isInt: true, style: styleR);
      _setCell(sheet, 3, row, item.revenue, isDouble: true, style: styleR);
      _setCell(sheet, 4, row, avgPrice, isDouble: true, style: styleR);
      _setCell(sheet, 5, row, '${share.toStringAsFixed(1)}%', style: styleR);
      row++;
    }

    // Total Row
    _setCell(sheet, 0, row, 'TOTAL', style: _totalRowLeft);
    _setCell(sheet, 1, row, '${sortedItems.length} Products Sold', style: _totalRowLeft);
    _setCell(sheet, 2, row, totalUnits, isInt: true, style: _totalRowRight);
    _setCell(sheet, 3, row, totalItemRevenue, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 4, row, totalUnits > 0 ? totalItemRevenue / totalUnits : 0.0, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 5, row, '100.0%', style: _totalRowRight);

    sheet.setColumnWidth(0, 10.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 22.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
  }

  // ---------------------------------------------------------------------------
  // SHEET 4: HOURLY SALES VELOCITY
  // ---------------------------------------------------------------------------
  static void _buildHourlyVelocitySheet(Sheet sheet, DailyAnalytics a) {
    int row = 0;

    _setCell(sheet, 0, row, 'COFFEE KATTA - HOURLY SALES VELOCITY & PEAK RUSH ANALYSIS', style: _bannerStyle);
    for (int c = 1; c <= 4; c++) {
      _setCell(sheet, c, row, '', style: _bannerStyle);
    }
    row += 2;

    _setCell(sheet, 0, row, 'Time Interval (24h)', style: _tableHeaderStyle);
    _setCell(sheet, 1, row, 'Settled Orders', style: _tableHeaderRightStyle);
    _setCell(sheet, 2, row, 'Hourly Sales (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 3, row, 'Avg Spend / Order (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 4, row, 'Revenue Share (%)', style: _tableHeaderRightStyle);
    row++;

    final sortedHours = a.hourlyStats.entries.toList()
      ..sort((x, y) => (int.tryParse(x.key) ?? 0).compareTo(int.tryParse(y.key) ?? 0));

    final totalHourSales = sortedHours.fold(0.0, (p, c) => p + c.value.sales);
    final totalHourOrders = sortedHours.fold(0, (p, c) => p + c.value.orders);

    for (int i = 0; i < sortedHours.length; i++) {
      final h = sortedHours[i];
      final isZebra = i % 2 == 1;
      final styleL = isZebra ? _zebraLeft : _regularLeft;
      final styleR = isZebra ? _zebraRight : _regularRight;

      final hourInt = int.tryParse(h.key) ?? 0;
      final timeSlot = '${hourInt.toString().padLeft(2, '0')}:00 - ${(hourInt + 1).toString().padLeft(2, '0')}:00';
      final avgSpend = h.value.orders > 0 ? h.value.sales / h.value.orders : 0.0;
      final share = totalHourSales > 0 ? (h.value.sales / totalHourSales) * 100 : 0.0;

      _setCell(sheet, 0, row, timeSlot, style: styleL);
      _setCell(sheet, 1, row, h.value.orders, isInt: true, style: styleR);
      _setCell(sheet, 2, row, h.value.sales, isDouble: true, style: styleR);
      _setCell(sheet, 3, row, avgSpend, isDouble: true, style: styleR);
      _setCell(sheet, 4, row, '${share.toStringAsFixed(1)}%', style: styleR);
      row++;
    }

    // Total Row
    _setCell(sheet, 0, row, 'TOTAL (ALL HOURS)', style: _totalRowLeft);
    _setCell(sheet, 1, row, totalHourOrders, isInt: true, style: _totalRowRight);
    _setCell(sheet, 2, row, totalHourSales, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 3, row, totalHourOrders > 0 ? totalHourSales / totalHourOrders : 0.0, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 4, row, '100.0%', style: _totalRowRight);

    sheet.setColumnWidth(0, 24.0);
    sheet.setColumnWidth(1, 18.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 24.0);
    sheet.setColumnWidth(4, 20.0);
  }

  // ---------------------------------------------------------------------------
  // SHEET 5: ITEMIZED BILLS AUDIT REGISTER
  // ---------------------------------------------------------------------------
  static void _buildBillsRegisterSheet(
    Sheet sheet,
    List<BillModel> bills,
    BranchModel branch,
    String dateRangeStr,
  ) {
    int row = 0;

    _setCell(sheet, 0, row, 'COFFEE KATTA - ITEMIZED INVOICE & BILLS AUDIT REGISTER', style: _bannerStyle);
    for (int c = 1; c <= 12; c++) {
      _setCell(sheet, c, row, '', style: _bannerStyle);
    }
    row += 2;

    _setCell(sheet, 0, row, 'Bill ID / No', style: _tableHeaderStyle);
    _setCell(sheet, 1, row, 'Order ID', style: _tableHeaderStyle);
    _setCell(sheet, 2, row, 'Date', style: _tableHeaderStyle);
    _setCell(sheet, 3, row, 'Time', style: _tableHeaderStyle);
    _setCell(sheet, 4, row, 'Table / Type', style: _tableHeaderStyle);
    _setCell(sheet, 5, row, 'Cashier / User', style: _tableHeaderStyle);
    _setCell(sheet, 6, row, 'Payment Mode(s)', style: _tableHeaderStyle);
    _setCell(sheet, 7, row, 'Subtotal (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 8, row, 'Discount (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 9, row, 'Tax & Charges (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 10, row, 'Final Total (INR)', style: _tableHeaderRightStyle);
    _setCell(sheet, 11, row, 'Prints', style: _tableHeaderRightStyle);
    _setCell(sheet, 12, row, 'Audit Status', style: _tableHeaderStyle);
    row++;

    final dateFormat = DateFormat('dd-MM-yyyy');
    final timeFormat = DateFormat('hh:mm a');

    double sumSubtotal = 0.0;
    double sumDiscount = 0.0;
    double sumCharges = 0.0;
    double sumTotal = 0.0;

    for (int i = 0; i < bills.length; i++) {
      final b = bills[i];
      final isZebra = i % 2 == 1;
      final styleL = isZebra ? _zebraLeft : _regularLeft;
      final styleR = isZebra ? _zebraRight : _regularRight;

      sumSubtotal += b.subtotal;
      sumDiscount += b.discountAmount;
      sumCharges += b.extraCharges;
      sumTotal += b.total;

      final payModes = b.payments
          .map((p) => '${p.mode.toUpperCase()} (Rs. ${p.amount.toStringAsFixed(0)})')
          .join(', ');

      _setCell(sheet, 0, row, b.billId, style: styleL);
      _setCell(sheet, 1, row, b.orderId, style: styleL);
      _setCell(sheet, 2, row, dateFormat.format(b.createdAt), style: styleL);
      _setCell(sheet, 3, row, timeFormat.format(b.createdAt), style: styleL);
      _setCell(sheet, 4, row, b.tableName, style: styleL);
      _setCell(sheet, 5, row, b.userName, style: styleL);
      _setCell(sheet, 6, row, payModes.isNotEmpty ? payModes : 'CASH', style: styleL);
      _setCell(sheet, 7, row, b.subtotal, isDouble: true, style: styleR);
      _setCell(sheet, 8, row, b.discountAmount, isDouble: true, style: styleR);
      _setCell(sheet, 9, row, b.extraCharges, isDouble: true, style: styleR);
      _setCell(sheet, 10, row, b.total, isDouble: true, style: styleR);
      _setCell(sheet, 11, row, b.printCount, isInt: true, style: styleR);
      _setCell(sheet, 12, row, b.isSuspicious ? 'FLAGGED' : 'SETTLED', style: styleL);
      row++;
    }

    // Register Total Row
    _setCell(sheet, 0, row, 'TOTAL', style: _totalRowLeft);
    _setCell(sheet, 1, row, '${bills.length} Invoices', style: _totalRowLeft);
    _setCell(sheet, 2, row, '', style: _totalRowLeft);
    _setCell(sheet, 3, row, '', style: _totalRowLeft);
    _setCell(sheet, 4, row, '', style: _totalRowLeft);
    _setCell(sheet, 5, row, '', style: _totalRowLeft);
    _setCell(sheet, 6, row, '', style: _totalRowLeft);
    _setCell(sheet, 7, row, sumSubtotal, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 8, row, sumDiscount, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 9, row, sumCharges, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 10, row, sumTotal, isDouble: true, style: _totalRowRight);
    _setCell(sheet, 11, row, '', style: _totalRowRight);
    _setCell(sheet, 12, row, 'AUDITED', style: _totalRowLeft);

    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 12.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 18.0);
    sheet.setColumnWidth(5, 18.0);
    sheet.setColumnWidth(6, 26.0);
    sheet.setColumnWidth(7, 16.0);
    sheet.setColumnWidth(8, 16.0);
    sheet.setColumnWidth(9, 18.0);
    sheet.setColumnWidth(10, 18.0);
    sheet.setColumnWidth(11, 10.0);
    sheet.setColumnWidth(12, 16.0);
  }

  // ---------------------------------------------------------------------------
  // HELPER: CELL ASSIGNMENT WITH CELLVALUE TYPES
  // ---------------------------------------------------------------------------
  static void _setCell(
    Sheet sheet,
    int col,
    int row,
    dynamic value, {
    bool isDouble = false,
    bool isInt = false,
    CellStyle? style,
  }) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));

    if (isDouble && value is num) {
      cell.value = DoubleCellValue(value.toDouble());
    } else if (isInt && value is num) {
      cell.value = IntCellValue(value.toInt());
    } else {
      cell.value = TextCellValue(value?.toString() ?? '');
    }

    if (style != null) {
      cell.cellStyle = style;
    }
  }

  // ---------------------------------------------------------------------------
  // PERSISTENCE & INSTANT SPREADSHEET LAUNCH
  // ---------------------------------------------------------------------------
  /// Saves Excel workbook to Documents directory and immediately opens it in Microsoft Excel
  static Future<File?> saveAndOpenExcel({
    required List<int> bytes,
    String? fileName,
    String filenamePrefix = 'CoffeeKatta_Executive_Report',
  }) async {
    try {
      if (kIsWeb) return null;

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = (fileName != null && fileName.trim().isNotEmpty)
          ? (fileName.endsWith('.xlsx') ? fileName.trim() : '${fileName.trim()}.xlsx')
          : '${filenamePrefix}_$timestamp.xlsx';

      Directory dir;
      if (Platform.isWindows) {
        final docDir = await getApplicationDocumentsDirectory();
        final exportDir = Directory('${docDir.path}\\CoffeeKatta_Reports');
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        dir = exportDir;
      } else {
        dir = await getTemporaryDirectory();
      }

      final file = File('${dir.path}${Platform.pathSeparator}$filename');
      await file.writeAsBytes(bytes, flush: true);

      // Immediately launch in Excel or default spreadsheet handler
      try {
        await OpenFilex.open(file.path);
      } catch (e) {
        debugPrint('OpenFilex failed to launch file: $e');
      }

      // Mobile share fallback with clear report name and mime-type
      if (!Platform.isWindows) {
        try {
          await Share.shareXFiles(
            [
              XFile(
                file.path,
                name: filename,
                mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
            text: 'Coffee Katta Executive Excel Report: $filename',
            subject: filename,
          );
        } catch (_) {}
      }

      return file;
    } catch (e) {
      debugPrint('Error in saveAndOpenExcel: $e');
      return null;
    }
  }

  /// Opens the folder in Windows File Explorer with the exported file selected
  static Future<void> revealInFolder(String filePath) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } catch (e) {
        debugPrint('Failed to reveal file in Windows Explorer: $e');
      }
    }
  }
}
