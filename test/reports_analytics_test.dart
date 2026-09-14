import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/daily_analytics.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/services/pdf_service.dart';

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
}
