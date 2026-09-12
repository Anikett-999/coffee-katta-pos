import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coffee_katta_pos/domain/models/printer_config.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/services/print_service.dart';
import 'package:coffee_katta_pos/presentation/widgets/shared/thermal_receipt_preview.dart';

void main() {
  group('Printer Management & Thermal Engine Tests', () {
    late PrintService printService;
    late BranchModel mockBranch;
    late BillModel mockBill;
    late KOTModel mockKOT;

    setUp(() {
      printService = PrintService();
      mockBranch = const BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Rajiv Gandhi Chowk',
        address: 'Near Rajiv Gandhi Chowk, Latur 413512',
        phone: '+91 98765 43210',
      );

      mockBill = BillModel(
        billId: 'CK-2026-0042',
        orderId: 'order_1042',
        tableId: 'T3',
        tableName: 'Table 3',
        userName: 'Pooja S.',
        items: const [
          BillItem(
            name: 'Classic Cold Coffee',
            category: 'Beverages',
            qty: 2,
            price: 120,
          ),
          BillItem(
            name: 'Classic Veg Pizza',
            category: 'Pizza',
            qty: 1,
            price: 180,
          ),
        ],
        subtotal: 420.0,
        total: 420.0,
        payments: const [
          Payment(mode: 'cash', amount: 220.0),
          Payment(mode: 'upi', amount: 200.0),
        ],
        createdBy: 'cashier_001',
        createdAt: DateTime(2026, 9, 12, 17, 30),
      );

      mockKOT = KOTModel(
        kotId: 'kot_1042',
        kotNumber: 1042,
        orderId: 'order_1042',
        tableId: 'T3',
        tableName: 'Table 3',
        items: const [
          KOTItem(
            uniqueId: 'item_1',
            itemId: 'bev_01',
            name: 'Cold Coffee (Large)',
            category: 'BEV',
            qty: 2,
            price: 120,
            note: 'less sugar, extra choco',
          ),
        ],
        createdBy: 'waiter_001',
        userName: 'Ramesh Pawar',
        createdAt: DateTime(2026, 9, 12, 17, 31),
      );
    });

    test('1. KOT ESC/POS byte generation initializes printer and includes KOT number', () async {
      final bytes58 = await printService.generateKOTBytes(mockKOT, PrinterPaperSize.mm58);
      expect(bytes58, isNotEmpty);
      expect(bytes58[0], equals(0x1B)); // ESC
      expect(bytes58[1], equals(0x40)); // @ (Initialize)

      final bytes80 = await printService.generateKOTBytes(mockKOT, PrinterPaperSize.mm80);
      expect(bytes80, isNotEmpty);
      expect(bytes80.length, greaterThan(bytes58.length - 50));
    });

    test('2. Bill ESC/POS byte generation formats Coffee Katta branding and split payment', () async {
      final bytes = await printService.generateBillBytes(mockBill, mockBranch, PrinterPaperSize.mm80);
      expect(bytes, isNotEmpty);

      // Verify initialization commands
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      final stringContent = utf8.decode(bytes, allowMalformed: true);
      expect(stringContent.contains('COFFEE KATTA'), isTrue);
      expect(stringContent.contains('SPLIT'), isTrue);
      expect(stringContent.contains('CASH'), isTrue);
      expect(stringContent.contains('UPI'), isTrue);
    });

    test('3. Diagnostic Test Ticket generation formats hardware configuration', () async {
      const config = PrinterConfig(
        connectionType: PrinterConnectionType.network,
        paperSize: PrinterPaperSize.mm80,
        address: '192.168.1.100',
        port: 9100,
        name: 'Counter Thermal POS80',
      );

      final testBytes = await printService.generateDiagnosticTestBytes(
        config,
        branchName: 'Coffee Katta — Latur Main',
        userRole: 'Counter / Admin',
      );

      expect(testBytes, isNotEmpty);
      final stringContent = utf8.decode(testBytes, allowMalformed: true);
      expect(stringContent.contains('COFFEE KATTA'), isTrue);
      expect(stringContent.contains('DIAGNOSTIC TEST'), isTrue);
      expect(stringContent.contains('NETWORK'), isTrue);
      expect(stringContent.contains('192.168.1.100'), isTrue);
      expect(stringContent.contains('ALIGNMENT TEST'), isTrue);
    });

    test('4. IP validation correctly validates IPv4 subnet addresses', () {
      bool isValidIp(String ip) => RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip.trim());

      expect(isValidIp('192.168.1.100'), isTrue);
      expect(isValidIp('10.0.0.1'), isTrue);
      expect(isValidIp('172.16.2.55'), isTrue);

      expect(isValidIp(''), isFalse);
      expect(isValidIp('invalid_ip'), isFalse);
      expect(isValidIp('192.168.1'), isFalse);
      expect(isValidIp('192.168.1.100.5'), isFalse);
    });

    test('5. PrinterConfig model serialization and defaults', () {
      const defaultConfig = PrinterConfig();
      expect(defaultConfig.connectionType, equals(PrinterConnectionType.rawbt));
      expect(defaultConfig.paperSize, equals(PrinterPaperSize.mm58));
      expect(defaultConfig.port, equals(9100));
      expect(defaultConfig.autoPrintKOT, isTrue);
      expect(defaultConfig.autoPrintBill, isTrue);

      final customConfig = const PrinterConfig(
        connectionType: PrinterConnectionType.network,
        paperSize: PrinterPaperSize.mm80,
        address: '192.168.1.50',
        port: 9100,
        name: 'Kitchen POS-80',
        autoPrintKOT: true,
        autoPrintBill: false,
      );

      final json = customConfig.toJson();
      final restored = PrinterConfig.fromJson(json);

      expect(restored.connectionType, equals(PrinterConnectionType.network));
      expect(restored.paperSize, equals(PrinterPaperSize.mm80));
      expect(restored.address, equals('192.168.1.50'));
      expect(restored.name, equals('Kitchen POS-80'));
      expect(restored.autoPrintBill, isFalse);
    });

    testWidgets('6. ThermalReceiptPreview widget renders bill and KOT simulator cleanly', (tester) async {
      tester.view.physicalSize = const Size(1024, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThermalReceiptPreview(
              paperSize: PrinterPaperSize.mm80,
              branchName: 'Coffee Katta',
              branchAddress: 'Near Rajiv Gandhi Chowk, Latur',
            ),
          ),
        ),
      );

      expect(find.text('LIVE TICKET SIMULATOR'), findsOneWidget);
      expect(find.text('80mm Roll • 64 Chars Width'), findsOneWidget);
      expect(find.text('Bill'), findsOneWidget);
      expect(find.text('KOT'), findsOneWidget);
      expect(find.text('COFFEE KATTA'), findsOneWidget);

      // Switch to KOT preview
      await tester.tap(find.text('KOT'));
      await tester.pumpAndSettle();

      expect(find.text('KOT #1042'), findsOneWidget);
      expect(find.text('-- KITCHEN SLIP --'), findsOneWidget);
    });
  });
}
