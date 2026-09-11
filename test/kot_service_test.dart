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

      } catch (e) {
        fail(e.toString());
      }
    });
  });
}
