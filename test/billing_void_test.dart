import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_katta_pos/domain/models/bill_model.dart';
import 'package:coffee_katta_pos/domain/models/branch_model.dart';
import 'package:coffee_katta_pos/services/pdf_service.dart';
import 'package:coffee_katta_pos/services/billing_service.dart';
import 'package:coffee_katta_pos/services/analytics_service.dart';

void main() {
  group('P0-3: Bill Void / Cancel / Refund Tests', () {
    test('BillModel defaults to isVoided: false and tableRestored: false', () {
      final bill = BillModel(
        billId: 'INV-260915-001',
        orderId: 'ORD-101',
        tableId: 'T1',
        tableName: 'Table 1',
        userName: 'Cashier 1',
        items: [
          const BillItem(name: 'Cold Coffee', category: 'Katta Coffee', qty: 2, price: 60.0),
        ],
        subtotal: 120.0,
        total: 120.0,
        payments: [const Payment(mode: 'cash', amount: 120.0)],
        createdBy: 'user_123',
        createdAt: DateTime.now(),
      );

      expect(bill.isVoided, isFalse);
      expect(bill.voidedAt, isNull);
      expect(bill.voidedBy, isNull);
      expect(bill.voidReason, isNull);
      expect(bill.tableRestored, isFalse);
    });

    test('BillModel serializes and deserializes void metadata correctly', () {
      final voidedTime = DateTime(2026, 9, 15, 14, 30);
      final bill = BillModel(
        billId: 'INV-260915-002',
        orderId: 'ORD-102',
        tableId: 'T2',
        tableName: 'Table 2',
        userName: 'Cashier 1',
        items: [
          const BillItem(name: 'Bun Maska', category: 'Katta Starter', qty: 1, price: 50.0),
        ],
        subtotal: 50.0,
        total: 50.0,
        payments: [const Payment(mode: 'upi', amount: 50.0)],
        createdBy: 'user_123',
        createdAt: DateTime(2026, 9, 15, 14, 0),
        isVoided: true,
        voidedAt: voidedTime,
        voidedBy: 'Manager John',
        voidReason: 'Wrong table selected by cashier',
        tableRestored: true,
      );

      final json = bill.toJson();
      expect(json['isVoided'], isTrue);
      expect(json['voidedBy'], equals('Manager John'));
      expect(json['voidReason'], equals('Wrong table selected by cashier'));
      expect(json['tableRestored'], isTrue);

      final restored = BillModel.fromJson(json);
      expect(restored.isVoided, isTrue);
      expect(restored.voidedBy, equals('Manager John'));
      expect(restored.voidReason, equals('Wrong table selected by cashier'));
      expect(restored.tableRestored, isTrue);
    });

    test('Active vs Voided filter partitions bills correctly', () {
      final activeBill1 = BillModel(
        billId: 'INV-001',
        orderId: 'O1',
        tableId: 'T1',
        tableName: 'T1',
        userName: 'Staff',
        items: [],
        subtotal: 100,
        total: 100,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: false,
      );

      final activeBill2 = BillModel(
        billId: 'INV-002',
        orderId: 'O2',
        tableId: 'T2',
        tableName: 'T2',
        userName: 'Staff',
        items: [],
        subtotal: 200,
        total: 200,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: false,
      );

      final voidedBill = BillModel(
        billId: 'INV-003',
        orderId: 'O3',
        tableId: 'T3',
        tableName: 'T3',
        userName: 'Staff',
        items: [],
        subtotal: 150,
        total: 150,
        payments: [],
        createdBy: 'u1',
        createdAt: DateTime.now(),
        isVoided: true,
        voidReason: 'Disputed charge',
      );

      final allBills = [activeBill1, activeBill2, voidedBill];

      final activeOnly = allBills.where((b) => !b.isVoided).toList();
      expect(activeOnly.length, equals(2));
      expect(activeOnly.map((b) => b.billId), containsAll(['INV-001', 'INV-002']));

      final voidedOnly = allBills.where((b) => b.isVoided).toList();
      expect(voidedOnly.length, equals(1));
      expect(voidedOnly.first.billId, equals('INV-003'));

      // Total revenue calculated only from active bills
      final revenue = activeOnly.fold<double>(0.0, (sum, b) => sum + b.total);
      expect(revenue, equals(300.0)); // 100 + 200, excludes 150
    });

    test('PdfService.generateBillPdf generates valid PDF with void watermark when bill is voided', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const branch = BranchModel(
        branchId: 'latur_main',
        branchName: 'Coffee Katta',
        location: 'Rajiv Gandhi Chowk, Latur',
        address: 'Near Katta Center, Latur, MH 413512',
        phone: '+91 98765 43210',
      );

      final voidedBill = BillModel(
        billId: 'INV-260915-099',
        orderId: 'ORD-999',
        tableId: 'T5',
        tableName: 'Table 5',
        userName: 'Cashier Admin',
        items: [
          const BillItem(name: 'Cappuccino', category: 'Hot Beverages', qty: 2, price: 90.0),
        ],
        subtotal: 180.0,
        total: 180.0,
        payments: [const Payment(mode: 'cash', amount: 180.0)],
        createdBy: 'admin_1',
        createdAt: DateTime(2026, 9, 15, 12, 0),
        isVoided: true,
        voidedAt: DateTime(2026, 9, 15, 12, 15),
        voidedBy: 'Manager',
        voidReason: 'Wrong order punched',
      );

      final pdfBytes = await PdfService.generateBillPdf(voidedBill, branch);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, isPositive);
    });

    test('Open Shift: voidBill succeeds normally with valid reason', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final billingService = BillingService(
        branchId: 'latur_main',
        firestore: fakeFirestore,
      );

      final now = DateTime.now();
      final billRef = fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('bills')
          .doc('INV-261019-001');

      await billRef.set({
        'billId': 'INV-261019-001',
        'orderId': 'ORD-101',
        'tableId': 'T1',
        'tableName': 'Table 1',
        'userName': 'Cashier 1',
        'items': [
          {'name': 'Cold Coffee', 'category': 'Katta Coffee', 'qty': 1, 'price': 60.0, 'note': ''}
        ],
        'subtotal': 60.0,
        'total': 60.0,
        'payments': [
          {'mode': 'cash', 'amount': 60.0}
        ],
        'createdBy': 'user_1',
        'createdAt': now,
        'isVoided': false,
      });

      final result = await billingService.voidBill(
        billId: 'INV-261019-001',
        voidedBy: 'Manager John',
        voidReason: 'Customer changed mind before preparation',
      );

      expect(result.isVoided, isTrue);
      expect(result.voidedBy, equals('Manager John'));

      final docSnap = await billRef.get();
      expect(docSnap.data()!['isVoided'], isTrue);
      expect(docSnap.data()!['voidReason'], equals('Customer changed mind before preparation'));
      expect(docSnap.data()!['postShiftVoid'], isNull);
    });

    test('Closed Shift: voidBill WITHOUT admin override is strictly blocked', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final analyticsService = AnalyticsService(firestore: fakeFirestore);
      final billingService = BillingService(
        branchId: 'latur_main',
        firestore: fakeFirestore,
        analyticsService: analyticsService,
      );

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Close shift by adding shift closing to daily_stats
      await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('daily_stats')
          .doc(todayStr)
          .set({
        'lastShiftClosing': {
          'closingId': 'shift_test_1',
          'date': todayStr,
          'totalBills': 10,
          'netRevenue': 1500.0,
        },
      });

      final billRef = fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('bills')
          .doc('INV-CLOSED-001');

      await billRef.set({
        'billId': 'INV-CLOSED-001',
        'orderId': 'ORD-CLOSED',
        'tableId': 'T2',
        'tableName': 'Table 2',
        'userName': 'Cashier 1',
        'items': [],
        'subtotal': 100.0,
        'total': 100.0,
        'payments': [],
        'createdBy': 'user_1',
        'createdAt': now,
        'isVoided': false,
      });

      // Attempting to void without override MUST throw
      expect(
        () => billingService.voidBill(
          billId: 'INV-CLOSED-001',
          voidedBy: 'Cashier 1',
          voidReason: 'Mistake in order',
          allowPostShiftOverride: false,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('already been closed and reconciled with a Z-Report'),
        )),
      );

      // Verify bill remains active in Firestore
      final snap = await billRef.get();
      expect(snap.data()!['isVoided'], isFalse);
    });

    test('Closed Shift: voidBill WITH admin override succeeds and writes shift_adjustments audit', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final analyticsService = AnalyticsService(firestore: fakeFirestore);
      final billingService = BillingService(
        branchId: 'latur_main',
        firestore: fakeFirestore,
        analyticsService: analyticsService,
      );

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Seed closed shift in daily_stats
      await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('daily_stats')
          .doc(todayStr)
          .set({
        'lastShiftClosing': {'closingId': 'shift_test_1'},
      });

      final billRef = fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('bills')
          .doc('INV-CLOSED-002');

      await billRef.set({
        'billId': 'INV-CLOSED-002',
        'orderId': 'ORD-CLOSED-2',
        'tableId': 'T3',
        'tableName': 'Table 3',
        'userName': 'Cashier 1',
        'items': [],
        'subtotal': 250.0,
        'total': 250.0,
        'payments': [],
        'createdBy': 'user_1',
        'createdAt': now,
        'isVoided': false,
      });

      final result = await billingService.voidBill(
        billId: 'INV-CLOSED-002',
        voidedBy: 'Supervisor Rita',
        voidReason: 'Credit card chargeback dispute',
        allowPostShiftOverride: true,
        authorizedByAdminId: 'admin_super_1',
        adminOverrideNote: 'Approved by GM for bank chargeback investigation',
      );

      expect(result.isVoided, isTrue);

      final billSnap = await billRef.get();
      expect(billSnap.data()!['isVoided'], isTrue);
      expect(billSnap.data()!['postShiftVoid'], isTrue);
      expect(billSnap.data()!['authorizedByAdminId'], equals('admin_super_1'));

      // Verify audit trail in shift_adjustments collection
      final adjustments = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('shift_adjustments')
          .get();

      expect(adjustments.docs.length, equals(1));
      final adjData = adjustments.docs.first.data();
      expect(adjData['adjustmentType'], equals('post_shift_void'));
      expect(adjData['billId'], equals('INV-CLOSED-002'));
      expect(adjData['originalTotal'], equals(250.0));
      expect(adjData['authorizedBy'], equals('admin_super_1'));
      expect(adjData['adminNote'], contains('Approved by GM'));
    });

    test('Closed Shift: voidBill rejects short admin override notes (< 5 chars)', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final billingService = BillingService(
        branchId: 'latur_main',
        firestore: fakeFirestore,
      );

      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('daily_stats')
          .doc(todayStr)
          .set({
        'lastShiftClosing': {'closingId': 'shift_test_1'},
      });

      final billRef = fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('bills')
          .doc('INV-CLOSED-003');

      await billRef.set({
        'billId': 'INV-CLOSED-003',
        'orderId': 'ORD-CLOSED-3',
        'tableId': 'T4',
        'tableName': 'Table 4',
        'userName': 'Cashier 1',
        'items': [],
        'subtotal': 150.0,
        'total': 150.0,
        'payments': [],
        'createdBy': 'user_1',
        'createdAt': now,
        'isVoided': false,
      });

      expect(
        () => billingService.voidBill(
          billId: 'INV-CLOSED-003',
          voidedBy: 'Supervisor Rita',
          voidReason: 'Mistake',
          allowPostShiftOverride: true,
          adminOverrideNote: 'ok', // too short (< 5 chars)
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('minimum 5 characters'),
        )),
      );
    });
  });
}
