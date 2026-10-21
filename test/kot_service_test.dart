import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';

void main() {
  group('KOTService Transaction Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late KOTService kotService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      kotService = KOTService(firestore: fakeFirestore);

      // Seed a table
      await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .set({
             'tableId': 'T3',
             'name': 'Table 3',
             'status': 'available',
             'capacity': 4,
             'activeOrderId': null
          });
    });

    test('createKOT atomic transaction generates order correctly', () async {
      try {
        final kot = await kotService.createKOT(
          tableId: 'T3',
          tableName: 'Table 3',
          items: [
            const KOTItem(
              uniqueId: 'item_1_test',
              itemId: 'I1',
              name: 'Classic Cold Coffee',
              category: 'C1',
              qty: 2,
              price: 120,
            ),
          ],
          userId: 'dev123',
          userName: 'Staff User',
        );

        expect(kot.kotNumber, equals(1001));
        expect(kot.items.length, equals(1));
        expect(kot.tableId, equals('T3'));

        final tableSnapshot = await fakeFirestore
           .collection('businesses')
           .doc('coffee_katta')
           .collection('branches')
           .doc('latur_main')
           .collection('tables')
           .doc('T3')
           .get();

        final tableData = tableSnapshot.data()!;
        expect(tableData['status'], equals('occupied'));
        expect(tableData['activeOrderId'], isNotNull);
        expect(tableData['kotCount'], equals(1));

        // Check order document
        final orderId = tableData['activeOrderId'] as String;
        final orderSnapshot = await fakeFirestore
            .collection('businesses')
            .doc('coffee_katta')
            .collection('branches')
            .doc('latur_main')
            .collection('orders')
            .doc(orderId)
            .get();
        final orderData = orderSnapshot.data()!;
        expect(orderData['kotIds'], equals([kot.kotId]));
        expect(orderData['createdAt'], isNotNull);

        // Check daily_stats document
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final dailyStatSnapshot = await fakeFirestore
            .collection('businesses')
            .doc('coffee_katta')
            .collection('branches')
            .doc('latur_main')
            .collection('daily_stats')
            .doc(todayStr)
            .get();
        expect(dailyStatSnapshot.exists, isTrue);
        final dailyStatData = dailyStatSnapshot.data()!;
        expect(dailyStatData['totalKots'], equals(1));
        expect(dailyStatData['lastKotNumber'], equals(1001));
        expect(dailyStatData['lastUpdated'], isNotNull);
      } catch (e) {
        fail(e.toString());
      }
    });

    test('createKOT appends to existing order on second KOT without FieldValue transforms', () async {
      // 1. Create first KOT
      final kot1 = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(
            uniqueId: 'item_1_test',
            itemId: 'I1',
            name: 'Classic Cold Coffee',
            category: 'C1',
            qty: 1,
            price: 120,
          ),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );
      expect(kot1.kotNumber, equals(1001));

      // 2. Create second KOT on same table with active order
      final kot2 = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(
            uniqueId: 'item_2_test',
            itemId: 'I2',
            name: 'Hazelnut Cold Coffee',
            category: 'C1',
            qty: 2,
            price: 140,
          ),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );
      expect(kot2.kotNumber, equals(1002));
      expect(kot2.orderId, equals(kot1.orderId));

      // 3. Verify order document contains both KOT IDs in order
      final orderSnapshot = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('orders')
          .doc(kot1.orderId)
          .get();
      final orderData = orderSnapshot.data()!;
      expect(orderData['kotIds'], equals([kot1.kotId, kot2.kotId]));

      // 4. Verify table counts updated correctly
      final tableSnapshot = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      final tableData = tableSnapshot.data()!;
      expect(tableData['kotCount'], equals(2));
      expect(tableData['totalAmount'], equals(120.0 + 280.0));
      expect(tableData['unprintedKotCount'], equals(2));
      expect(tableData['updatedAt'], isNotNull);
    });

    test('CONCURRENCY: Simultaneous KOT dispatches produce unique incremented numbers without collision', () async {
      // Seed a second table T4
      await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T4')
          .set({
             'tableId': 'T4',
             'name': 'Table 4',
             'status': 'available',
             'capacity': 2,
             'activeOrderId': null
          });

      // Fire 2 KOT creations simultaneously using Future.wait
      final results = await Future.wait([
        kotService.createKOT(
          tableId: 'T3',
          tableName: 'Table 3',
          items: [
            const KOTItem(uniqueId: 'item_c1', itemId: 'I1', name: 'Coffee', category: 'C1', qty: 1, price: 100),
          ],
          userId: 'waiter_1',
          userName: 'Waiter 1',
        ),
        kotService.createKOT(
          tableId: 'T4',
          tableName: 'Table 4',
          items: [
            const KOTItem(uniqueId: 'item_c2', itemId: 'I2', name: 'Tea', category: 'C1', qty: 1, price: 50),
          ],
          userId: 'waiter_2',
          userName: 'Waiter 2',
        ),
      ]);

      final kotA = results[0];
      final kotB = results[1];

      // Verify ZERO collision
      expect(kotA.kotNumber, isNot(equals(kotB.kotNumber)));
      final numbers = [kotA.kotNumber, kotB.kotNumber]..sort();
      expect(numbers[0], equals(1001));
      expect(numbers[1], equals(1002));
    });

    test('cancelUnprintedKot safely rolls back table to available and activeOrderId to null if only KOT', () async {
      // 1. Create a KOT
      final kot = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(uniqueId: 'item_c_1', itemId: 'I1', name: 'Cold Coffee', category: 'C1', qty: 2, price: 100),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );

      // Verify table is occupied with 1 unprinted KOT
      var tableSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      expect(tableSnap.data()!['status'], equals('occupied'));
      expect(tableSnap.data()!['unprintedKotCount'], equals(1));
      expect(tableSnap.data()!['totalAmount'], equals(200.0));

      // 2. Cancel the unprinted KOT
      await kotService.cancelUnprintedKot(kotId: kot.kotId, tableId: 'T3');

      // 3. Verify KOT document was deleted
      final kotDoc = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('kots')
          .doc(kot.kotId)
          .get();
      expect(kotDoc.exists, isFalse);

      // 4. Verify table is completely reset to available and activeOrderId is null
      tableSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      final tableData = tableSnap.data()!;
      expect(tableData['status'], equals('available'));
      expect(tableData['activeOrderId'], isNull);
      expect(tableData['totalAmount'], equals(0.0));
      expect(tableData['itemCount'], equals(0));
      expect(tableData['kotCount'], equals(0));
      expect(tableData['unprintedKotCount'], equals(0));

      // 5. Verify order is marked cancelled
      final orderSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('orders')
          .doc(kot.orderId)
          .get();
      expect(orderSnap.data()!['status'], equals('cancelled'));
      expect(orderSnap.data()!['kotIds'], isEmpty);
    });

    test('cancelUnprintedKot maintains active order and decrements table amounts if other KOTs remain', () async {
      // 1. Create first KOT
      final kot1 = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(uniqueId: 'item_1', itemId: 'I1', name: 'Cold Coffee', category: 'C1', qty: 1, price: 100),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );
      // Mark first KOT as printed
      await kotService.markAsPrinted(kot1.kotId, 'T3');

      // 2. Create second KOT on same table
      final kot2 = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(uniqueId: 'item_2', itemId: 'I2', name: 'Sandwich', category: 'C2', qty: 1, price: 150),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );

      var tableSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      expect(tableSnap.data()!['kotCount'], equals(2));
      expect(tableSnap.data()!['unprintedKotCount'], equals(1));
      expect(tableSnap.data()!['totalAmount'], equals(250.0));

      // 3. Cancel the second unprinted KOT
      await kotService.cancelUnprintedKot(kotId: kot2.kotId, tableId: 'T3');

      // 4. Verify table remains occupied with KOT 1
      tableSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      final tableData = tableSnap.data()!;
      expect(tableData['status'], equals('occupied'));
      expect(tableData['activeOrderId'], equals(kot1.orderId));
      expect(tableData['kotCount'], equals(1));
      expect(tableData['unprintedKotCount'], equals(0));
      expect(tableData['totalAmount'], equals(100.0));

      // 5. Verify order retains kot1
      final orderSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('orders')
          .doc(kot1.orderId)
          .get();
      expect(orderSnap.data()!['kotIds'], equals([kot1.kotId]));
      expect(orderSnap.data()!['status'], isNot(equals('cancelled')));
    });

    test('removeKotItem reverts table status to available and activeOrderId to null when last item is removed', () async {
      // 1. Create a KOT with 1 item
      final kot = await kotService.createKOT(
        tableId: 'T3',
        tableName: 'Table 3',
        items: [
          const KOTItem(uniqueId: 'item_rem_1', itemId: 'I1', name: 'Cold Coffee', category: 'C1', qty: 1, price: 100),
        ],
        userId: 'dev123',
        userName: 'Staff User',
      );

      // 2. Remove the only item from the KOT
      await kotService.removeKotItem(kotId: kot.kotId, itemUniqueId: 'item_rem_1');

      // 3. Verify table automatically transitions from occupied to available
      final tableSnap = await fakeFirestore
          .collection('businesses')
          .doc('coffee_katta')
          .collection('branches')
          .doc('latur_main')
          .collection('tables')
          .doc('T3')
          .get();
      final tableData = tableSnap.data()!;
      expect(tableData['status'], equals('available'));
      expect(tableData['activeOrderId'], isNull);
      expect(tableData['kotCount'], equals(0));
      expect(tableData['totalAmount'], equals(0.0));
      expect(tableData['itemCount'], equals(0));
    });
  });
}
