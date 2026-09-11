import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';

void main() async {
  try {
    final fakeFirestore = FakeFirebaseFirestore();
    final kotService = KOTService(firestore: fakeFirestore);

    await fakeFirestore
        .collection('businesses')
        .doc('rajmandir_main')
        .collection('branches')
        .doc('branch_001')
        .collection('tables')
        .doc('T3')
        .set({
           'tableId': 'T3',
           'name': 'Table 3',
           'status': 'available',
           'capacity': 4,
           'activeOrderId': null
        });

    print('Table seeded');

    final kot = await kotService.createKOT(
      tableId: 'T3',
      tableName: 'Table 3',
      items: [
        const KOTItem(
          uniqueId: 'cart_item_1',
          itemId: 'I1',
          name: 'Vanilla Ice Cream',
          category: 'C1',
          qty: 2,
          price: 100,
        ),
      ],
      userId: 'dev123',
      userName: 'Developer Admin',
    );

    print('KOT Created! KOT ID: ${kot.kotId}');
  } catch (e, stackTrace) {
    print('ERROR CAUGHT!!! => $e');
    print(stackTrace);
  }
}
