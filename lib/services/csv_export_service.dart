import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/models/daily_analytics.dart';
import '../domain/models/branch_model.dart';
import '../domain/models/bill_model.dart';

class CsvExportService {
  static String _escapeCsv(dynamic value) {
    if (value == null) return '""';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Generates a comprehensive CSV summary of sales, payments, categories, and items
  static String generateSummaryCsv({
    required DailyAnalytics analytics,
    required BranchModel branch,
    required String dateRangeStr,
  }) {
    final buffer = StringBuffer();
    final genTime = DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());

    // Header metadata
    buffer.writeln('COFFEE KATTA - BUSINESS SALES & ANALYTICS REPORT');
    buffer.writeln('Branch,${_escapeCsv(branch.branchName)}');
    buffer.writeln('Location,${_escapeCsv(branch.location)}');
    buffer.writeln('Address,${_escapeCsv(branch.address)}');
    buffer.writeln('Phone,${_escapeCsv(branch.phone)}');
    buffer.writeln('Period,${_escapeCsv(dateRangeStr)}');
    buffer.writeln('Generated At,${_escapeCsv(genTime)}');
    buffer.writeln();

    // Financial KPIs
    final grossSales = analytics.totalSales + analytics.totalDiscount - analytics.extraCharges;
    final netRevenue = analytics.totalSales;
    final aov = analytics.totalBills > 0 ? netRevenue / analytics.totalBills : 0.0;

    buffer.writeln('=== FINANCIAL PERFORMANCE ===');
    buffer.writeln('Metric,Amount (INR)');
    buffer.writeln('Gross Food & Beverage Sales,${grossSales.toStringAsFixed(2)}');
    buffer.writeln('Total Discounts,${analytics.totalDiscount.toStringAsFixed(2)}');
    buffer.writeln('Net F&B Sales,${(grossSales - analytics.totalDiscount).toStringAsFixed(2)}');
    buffer.writeln('Extra / Packaging Charges,${analytics.extraCharges.toStringAsFixed(2)}');
    buffer.writeln('Total Net Revenue,${netRevenue.toStringAsFixed(2)}');
    buffer.writeln('Total Orders / Invoices,${analytics.totalBills}');
    buffer.writeln('Average Ticket Size (AOV),${aov.toStringAsFixed(2)}');
    buffer.writeln();

    // Payment Tender Breakdown
    buffer.writeln('=== PAYMENT SUMMARY ===');
    buffer.writeln('Payment Mode,Amount (INR),Percentage Share');
    final totalPayment = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
    for (var entry in analytics.paymentStats.entries) {
      final pct = totalPayment > 0 ? (entry.value / totalPayment) * 100 : 0.0;
      buffer.writeln('${_escapeCsv(entry.key.toUpperCase())},${entry.value.toStringAsFixed(2)},${pct.toStringAsFixed(1)}%');
    }
    buffer.writeln('Total Payments Collected,${totalPayment.toStringAsFixed(2)},100.0%');
    buffer.writeln();

    // Category Breakdown
    if (analytics.categoryStats.isNotEmpty) {
      buffer.writeln('=== CATEGORY BREAKDOWN ===');
      buffer.writeln('Category,Revenue (INR),Share');
      final sortedCats = analytics.categoryStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var cat in sortedCats) {
        final pct = grossSales > 0 ? (cat.value / grossSales) * 100 : 0.0;
        buffer.writeln('${_escapeCsv(cat.key)},${cat.value.toStringAsFixed(2)},${pct.toStringAsFixed(1)}%');
      }
      buffer.writeln();
    }

    // Staff Performance
    if (analytics.userStats.isNotEmpty) {
      buffer.writeln('=== STAFF SALES CONTRIBUTION ===');
      buffer.writeln('Staff Member,Total Sales (INR)');
      final sortedStaff = analytics.userStats.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (var staff in sortedStaff) {
        buffer.writeln('${_escapeCsv(staff.key)},${staff.value.toStringAsFixed(2)}');
      }
      buffer.writeln();
    }

    // Detailed Item Sales
    if (analytics.itemStats.isNotEmpty) {
      buffer.writeln('=== MENU ITEM PERFORMANCE (RANKED BY REVENUE) ===');
      buffer.writeln('Rank,Item Name,Quantity Sold,Total Revenue (INR),Average Price (INR)');
      final sortedItems = analytics.itemStats.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));
      int rank = 1;
      for (var item in sortedItems) {
        final avgPrice = item.qty > 0 ? item.revenue / item.qty : 0.0;
        buffer.writeln('$rank,${_escapeCsv(item.name)},${item.qty},${item.revenue.toStringAsFixed(2)},${avgPrice.toStringAsFixed(2)}');
        rank++;
      }
      buffer.writeln();
    }

    // Hourly Distribution
    if (analytics.hourlyStats.isNotEmpty) {
      buffer.writeln('=== HOURLY SALES DISTRIBUTION ===');
      buffer.writeln('Hour Window,Orders,Revenue (INR)');
      for (int h = 0; h < 24; h++) {
        final hKey = h.toString();
        final stat = analytics.hourlyStats[hKey];
        final timeLabel = '${h.toString().padLeft(2, '0')}:00 - ${(h + 1).toString().padLeft(2, '0')}:00';
        if (stat != null && (stat.orders > 0 || stat.sales > 0)) {
          buffer.writeln('$timeLabel,${stat.orders},${stat.sales.toStringAsFixed(2)}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Generates an itemized CSV of all individual bills
  static String generateBillsRegisterCsv({
    required List<BillModel> bills,
    required BranchModel branch,
    required String dateRangeStr,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('COFFEE KATTA - INVOICE REGISTER');
    buffer.writeln('Branch,${_escapeCsv(branch.branchName)}');
    buffer.writeln('Period,${_escapeCsv(dateRangeStr)}');
    buffer.writeln();
    buffer.writeln('Invoice No,Date,Time,Table,Cashier,Items Count,Subtotal,Discount,Extra Charges,Net Total,Payment Mode,Print Count');

    final dateFormat = DateFormat('dd-MM-yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    for (var b in bills) {
      final itemsCount = b.items.fold(0, (acc, item) => acc + item.qty);
      final paymentModes = b.payments.map((p) => '${p.mode.toUpperCase()}: ₹${p.amount.toStringAsFixed(0)}').join('; ');
      buffer.writeln([
        _escapeCsv(b.billId),
        _escapeCsv(dateFormat.format(b.createdAt)),
        _escapeCsv(timeFormat.format(b.createdAt)),
        _escapeCsv(b.tableName),
        _escapeCsv(b.userName),
        itemsCount,
        b.subtotal.toStringAsFixed(2),
        b.discountAmount.toStringAsFixed(2),
        b.extraCharges.toStringAsFixed(2),
        b.total.toStringAsFixed(2),
        _escapeCsv(paymentModes),
        b.printCount,
      ].join(','));
    }

    return buffer.toString();
  }

  /// Saves CSV to local storage and shares or reveals path
  static Future<File?> saveAndShareCsv({
    required String csvContent,
    required String filenamePrefix,
  }) async {
    try {
      if (kIsWeb) {
        // Web does not support dart:io File/Directory
        return null;
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${filenamePrefix}_$timestamp.csv';

      Directory dir;
      if (Platform.isWindows) {
        // On Windows, save to Documents or Downloads folder for easy access
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
      await file.writeAsString(csvContent);

      if (!Platform.isWindows) {
        await Share.shareXFiles([XFile(file.path)], text: 'Coffee Katta Analytics Report');
      }

      return file;
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      return null;
    }
  }
}
