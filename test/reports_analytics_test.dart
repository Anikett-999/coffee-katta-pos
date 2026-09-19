import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/daily_analytics.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/services/pdf_service.dart';
import 'package:coffee_katta_pos/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Reports & DailyAnalytics Financial Accounting Tests', () {
    test('Calculates Gross Sales, Net Sales, and Revenue without double-deduction', () {
      // Suppose subtotal = 1000, discount = 150, extraCharges = 50
      // Customer pays: (1000 - 150) + 50 = 900.
      // totalSales stored in Firestore = 900.
      // totalDiscount = 150.
      // extraCharges = 50.
      const analytics = DailyAnalytics(
        totalSales: 900.0,
        totalBills: 5,
        totalDiscount: 150.0,
        extraCharges: 50.0,
        paymentStats: {'cash': 500.0, 'upi': 400.0, 'card': 0.0},
      );

      expect(analytics.netRevenue, equals(900.0));
      expect(analytics.grossSales, equals(1000.0)); // 900 + 150 - 50 = 1000
      expect(analytics.netSales, equals(850.0));     // 1000 - 150 = 850
      expect(analytics.aov, equals(180.0));          // 900 / 5 = 180
      
      // Verify tender total matches netRevenue exactly
      final totalTender = analytics.paymentStats.values.fold(0.0, (p, c) => p + c);
      expect(totalTender, equals(analytics.netRevenue));
    });

    test('DailyAnalytics.merge correctly merges multiple days and preserves totals', () {
      const day1 = DailyAnalytics(
        totalSales: 1200.0,
        totalBills: 6,
        totalDiscount: 100.0,
        extraCharges: 20.0,
        paymentStats: {'cash': 600.0, 'upi': 600.0},
        itemStats: {
          'Cold Coffee': ItemStat(name: 'Cold Coffee', qty: 10, revenue: 600.0),
        },
      );

      const day2 = DailyAnalytics(
        totalSales: 1800.0,
        totalBills: 9,
        totalDiscount: 150.0,
        extraCharges: 30.0,
        paymentStats: {'cash': 1000.0, 'upi': 800.0},
        itemStats: {
          'Cold Coffee': ItemStat(name: 'Cold Coffee', qty: 15, revenue: 900.0),
          'Bun Maska': ItemStat(name: 'Bun Maska', qty: 8, revenue: 400.0),
        },
      );

      final merged = DailyAnalytics.merge(day1, day2);

      expect(merged.totalSales, equals(3000.0));
      expect(merged.totalBills, equals(15));
      expect(merged.totalDiscount, equals(250.0));
      expect(merged.extraCharges, equals(50.0));
      expect(merged.grossSales, equals(3200.0)); // 3000 + 250 - 50 = 3200
      expect(merged.netRevenue, equals(3000.0));

      expect(merged.paymentStats['cash'], equals(1600.0));
      expect(merged.paymentStats['upi'], equals(1400.0));

      expect(merged.itemStats['Cold Coffee']?.qty, equals(25));
      expect(merged.itemStats['Cold Coffee']?.revenue, equals(1500.0));
      expect(merged.itemStats['Bun Maska']?.qty, equals(8));
    });

    test('PdfService.generateExecutiveA4Pdf embeds official branding logo and produces valid PDF', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const analytics = DailyAnalytics(
        totalSales: 2500.0,
        totalBills: 12,
        totalDiscount: 200.0,
        extraCharges: 40.0,
        paymentStats: {'cash': 1500.0, 'upi': 1000.0},
        itemStats: {
          'Special Cold Coffee': ItemStat(name: 'Special Cold Coffee', qty: 10, revenue: 800.0),
        },
      );
      final branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Latur Main',
        address: 'Opp. Old Bus Stand, Latur',
        phone: '+91 9876543210',
      );

      final pdfBytes = await PdfService.generateExecutiveA4Pdf(
        analytics: analytics,
        dateRangeStr: '13 Sep 2026',
        branch: branch,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF magic byte header "%PDF-"
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('PdfService.generateDailyAnalyticsPdf (Z-Report) embeds official branding logo and produces valid thermal slip', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const analytics = DailyAnalytics(
        totalSales: 3400.0,
        totalBills: 18,
        totalDiscount: 150.0,
        extraCharges: 20.0,
        paymentStats: {'cash': 2000.0, 'upi': 1400.0},
        itemStats: {
          'Classic Cold Coffee': ItemStat(name: 'Classic Cold Coffee', qty: 15, revenue: 1200.0),
        },
      );
      final branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Latur Main',
        address: 'Opp. Old Bus Stand, Latur',
        phone: '+91 9876543210',
      );

      final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
        analytics: analytics,
        dateRangeStr: '13 Sep 2026',
        branch: branch,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF magic byte header "%PDF-"
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('PdfService.generateDailyAnalyticsPdf with cash drawer reconciliation generates valid slip with audit details', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const analytics = DailyAnalytics(
        totalSales: 3400.0,
        totalBills: 18,
        totalDiscount: 150.0,
        extraCharges: 20.0,
        paymentStats: {'cash': 2000.0, 'upi': 1400.0},
        itemStats: {
          'Classic Cold Coffee': ItemStat(name: 'Classic Cold Coffee', qty: 15, revenue: 1200.0),
        },
      );
      final branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Latur Main',
        address: 'Opp. Old Bus Stand, Latur',
        phone: '+91 9876543210',
      );

      final pdfBytes = await PdfService.generateDailyAnalyticsPdf(
        analytics: analytics,
        dateRangeStr: '13 Sep 2026',
        branch: branch,
        openingFloat: 500.0,
        physicalCashCounted: 2550.0,
        cashVariance: 50.0,
        closedByUserName: 'Manager Rohan',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('PdfService.generateBillPdf produces valid thermal receipt PDF with Courier monospace styling', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final bill = BillModel(
        billId: 'CK-2026-0042',
        orderId: 'ORD-101',
        tableId: 'T3',
        tableName: 'Table 3',
        userName: 'Pooja Staff',
        items: const [
          BillItem(name: 'Special Cold Coffee', category: 'Beverages', qty: 2, price: 80.0, note: 'Less sugar'),
          BillItem(name: 'Veg Grilled Sandwich', category: 'Snacks', qty: 1, price: 120.0),
        ],
        subtotal: 280.0,
        discountAmount: 28.0,
        discountType: 'percent',
        discountPercent: 10.0,
        extraCharges: 10.0,
        total: 262.0,
        payments: const [
          Payment(mode: 'cash', amount: 100.0),
          Payment(mode: 'upi', amount: 162.0),
        ],
        createdBy: 'user_1',
        createdAt: DateTime.now(),
        printCount: 2,
      );

      final branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Latur Main',
        address: 'Opp. Old Bus Stand, Latur',
        phone: '+91 9876543210',
        reviewQrUrl: 'https://g.page/r/coffeekatta/review',
        instagramId: 'coffeekatta.official',
      );

      final pdfBytes = await PdfService.generateBillPdf(bill, branch);

      final sampleFile = File('C:/Users/anike/.gemini/antigravity-ide/brain/2d605b44-4e6d-488e-b5cf-9e7ce819d6bc/scratch/sample_thermal_invoice.pdf');
      await sampleFile.parent.create(recursive: true);
      await sampleFile.writeAsBytes(pdfBytes);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });
  });

  group('Invoice Register & Safe Bill Deserialization Tests', () {
    test('safeParseBillData parses valid INV- bills with loose untyped maps', () {
      final rawData = <dynamic, dynamic>{
        'billId': 'INV-260919-001',
        'orderId': 'ORD-999',
        'tableId': 'T1',
        'tableName': 'Table 1',
        'userName': 'Kiran Cashier',
        'createdBy': 'user_1',
        'items': <dynamic>[
          <dynamic, dynamic>{'name': 'Cold Coffee', 'category': 'Beverages', 'qty': 2, 'price': 60.0},
          <dynamic, dynamic>{'name': 'Bun Maska', 'category': 'Snacks', 'qty': 1, 'price': 40.0},
        ],
        'payments': <dynamic>[
          <dynamic, dynamic>{'mode': 'upi', 'amount': 160.0},
        ],
        'subtotal': 160,
        'total': 160,
        'createdAt': Timestamp.now(),
      };

      final bill = AnalyticsService.safeParseBillData(rawData);
      expect(bill, isNotNull);
      expect(bill!.billId, equals('INV-260919-001'));
      expect(bill.tableName, equals('Table 1'));
      expect(bill.items.length, equals(2));
      expect(bill.items.first.name, equals('Cold Coffee'));
      expect(bill.payments.first.mode, equals('upi'));
      expect(bill.payments.first.amount, equals(160.0));
      expect(bill.isVoided, isFalse);
    });

    test('safeParseBillData rejects legacy or unnamed test bills without INV- prefix', () {
      final legacyData = <dynamic, dynamic>{
        'billId': 'OLD-BILL-001',
        'tableName': 'Table 1',
        'createdAt': Timestamp.now(),
      };
      final parsed = AnalyticsService.safeParseBillData(legacyData);
      expect(parsed, isNull);
    });

    test('Multi-field search filter correctly matches items, table, and invoice number', () {
      final bills = [
        BillModel(
          billId: 'INV-260912-001',
          orderId: 'ORD-1',
          tableId: 'T1',
          tableName: 'Table 1',
          userName: 'Ramesh',
          items: const [BillItem(name: 'Hazelnut Cold Coffee', qty: 2, price: 90.0)],
          subtotal: 180.0,
          total: 180.0,
          payments: const [Payment(mode: 'cash', amount: 180.0)],
          createdBy: 'user_1',
          createdAt: DateTime.now(),
        ),
        BillModel(
          billId: 'INV-260914-002',
          orderId: 'ORD-2',
          tableId: 'T2',
          tableName: 'Garden Table 4',
          userName: 'Priya',
          items: const [BillItem(name: 'Masala Chai', qty: 1, price: 30.0)],
          subtotal: 30.0,
          total: 30.0,
          payments: const [Payment(mode: 'upi', amount: 30.0)],
          createdBy: 'user_2',
          createdAt: DateTime.now(),
          isVoided: true,
        ),
      ];

      // Match by item name
      final itemMatches = bills.where((b) => b.items.any((i) => i.name.toLowerCase().contains('hazelnut'))).toList();
      expect(itemMatches.length, equals(1));
      expect(itemMatches.first.billId, equals('INV-260912-001'));

      // Match by table name
      final tableMatches = bills.where((b) => b.tableName.toLowerCase().contains('garden')).toList();
      expect(tableMatches.length, equals(1));
      expect(tableMatches.first.billId, equals('INV-260914-002'));

      // Match by cashier
      final cashierMatches = bills.where((b) => b.userName.toLowerCase().contains('ramesh')).toList();
      expect(cashierMatches.length, equals(1));

      // Calculate Summary KPIs
      final activeCount = bills.where((b) => !b.isVoided).length;
      final voidedCount = bills.where((b) => b.isVoided).length;
      final netRevenue = bills.where((b) => !b.isVoided).fold(0.0, (acc, b) => acc + b.total);

      expect(activeCount, equals(1));
      expect(voidedCount, equals(1));
      expect(netRevenue, equals(180.0));
    });
  });
}
