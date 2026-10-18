import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_katta_pos/services/table_service.dart';

void main() {
  group('TableService Unbilled Table Clear Guard Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late TableService tableService;
    const String businessId = 'coffee_katta';
    const String branchId = 'latur_main';

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      tableService = TableService(
        branchId: branchId,
        firestore: fakeFirestore,
      );

      // Seed an empty table T1
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T1')
          .set({
        'tableId': 'T1',
        'name': 'Table 1',
        'status': 'available',
        'capacity': 2,
        'activeOrderId': null,
        'totalAmount': 0.0,
        'itemCount': 0,
      });

      // Seed an occupied table T2 with an active order (unbilled)
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T2')
          .set({
        'tableId': 'T2',
        'name': 'Table 2',
        'status': 'occupied',
        'capacity': 4,
        'activeOrderId': 'order_unbilled_123',
        'totalAmount': 450.0,
        'itemCount': 3,
      });

      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('orders')
          .doc('order_unbilled_123')
          .set({
        'orderId': 'order_unbilled_123',
        'tableId': 'T2',
        'status': 'active',
        'kotIds': ['kot_test_1'],
        'createdAt': DateTime.now(),
      });
    });

    test('1. Clearing an empty table (0 amount / 0 items) succeeds cleanly', () async {
      await tableService.clearTable('T1');

      final tableSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T1')
          .get();

      expect(tableSnap.data()!['status'], equals('available'));
      expect(tableSnap.data()!['totalAmount'], equals(0.0));
    });

    test('2. Clearing an occupied table with unpaid food BLOCKS and throws exception', () async {
      expect(
        () async => await tableService.clearTable('T2'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('has not been billed'),
          ),
        ),
      );

      // Verify table is STILL occupied and totalAmount is NOT erased
      final tableSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T2')
          .get();

      expect(tableSnap.data()!['status'], equals('occupied'));
      expect(tableSnap.data()!['totalAmount'], equals(450.0));
      expect(tableSnap.data()!['activeOrderId'], equals('order_unbilled_123'));
    });

    test('3. Clearing an occupied table succeeds if a settled bill exists', () async {
      // Seed a settled bill for order_unbilled_123
      await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('bills')
          .doc('INV-261018-001')
          .set({
        'billId': 'INV-261018-001',
        'orderId': 'order_unbilled_123',
        'tableId': 'T2',
        'total': 450.0,
      });

      await tableService.clearTable('T2');

      final tableSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T2')
          .get();

      expect(tableSnap.data()!['status'], equals('available'));
      expect(tableSnap.data()!['activeOrderId'], isNull);
      expect(tableSnap.data()!['totalAmount'], equals(0.0));

      final orderSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('orders')
          .doc('order_unbilled_123')
          .get();

      expect(orderSnap.data()!['status'], equals('closed'));
    });

    test('4. Clearing unbilled table with Manager Abandonment Reason succeeds and logs audit', () async {
      await tableService.clearTable(
        'T2',
        abandonReason: 'Customer walked out without paying after argument',
        authorizedBy: 'manager_admin_99',
      );

      // Verify table is freed
      final tableSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('tables')
          .doc('T2')
          .get();

      expect(tableSnap.data()!['status'], equals('available'));
      expect(tableSnap.data()!['activeOrderId'], isNull);

      // Verify order is marked abandoned with audit record
      final orderSnap = await fakeFirestore
          .collection('businesses')
          .doc(businessId)
          .collection('branches')
          .doc(branchId)
          .collection('orders')
          .doc('order_unbilled_123')
          .get();

      expect(orderSnap.data()!['status'], equals('abandoned'));
      expect(orderSnap.data()!['abandonReason'], contains('Customer walked out'));
      expect(orderSnap.data()!['abandonedBy'], equals('manager_admin_99'));
    });

    test('5. Reject short or empty abandon reasons (< 5 chars)', () async {
      expect(
        () async => await tableService.clearTable(
          'T2',
          abandonReason: 'skip',
          authorizedBy: 'manager_admin_99',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
