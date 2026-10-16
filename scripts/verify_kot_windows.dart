import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coffee_katta_pos/firebase_options.dart';
import 'package:coffee_katta_pos/services/kot_service.dart';
import 'package:coffee_katta_pos/domain/models/kot_model.dart';
import 'package:coffee_katta_pos/domain/models/printer_config.dart';
import 'package:coffee_katta_pos/services/print_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('=============================================');
  print('Starting Live Windows Firestore KOT Test...');
  print('=============================================');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully on Windows desktop.');

    final firestore = FirebaseFirestore.instance;
    final kotService = KOTService(firestore: firestore, branchId: 'latur_main');

    // Generate a unique diagnostic table ID
    final testTableId = 'TEST_TBL_${DateTime.now().millisecondsSinceEpoch}';
    final tableRef = firestore
        .collection('businesses')
        .doc('coffee_katta')
        .collection('branches')
        .doc('latur_main')
        .collection('tables')
        .doc(testTableId);

    // Seed test table
    await tableRef.set({
      'tableId': testTableId,
      'name': 'Diagnostic Table',
      'status': 'available',
      'capacity': 4,
      'activeOrderId': null,
    });
    print('✅ Seeded test table in live Firestore: $testTableId');

    // TEST 1: First KOT (SEND workflow)
    print('\n--- TEST 1: Executing SEND workflow (create new order + KOT) ---');
    final kot1 = await kotService.createKOT(
      tableId: testTableId,
      tableName: 'Diagnostic Table',
      items: [
        const KOTItem(
          uniqueId: 'test_item_send_1',
          itemId: 'DIAG_01',
          name: 'Classic Espresso',
          category: 'Coffee',
          qty: 2,
          price: 90.0,
        ),
      ],
      userId: 'test_forensic_agent',
      userName: 'Diagnostic Agent',
    );

    print('✅ TEST 1 PASSED: KOT #${kot1.kotNumber} created successfully! (kotId: ${kot1.kotId}, orderId: ${kot1.orderId})');

    // Verify in Firestore
    final tableSnap1 = await tableRef.get();
    final tableData1 = tableSnap1.data()!;
    assert(tableData1['status'] == 'occupied', 'Table status should be occupied');
    assert(tableData1['activeOrderId'] == kot1.orderId, 'Table activeOrderId must match');
    assert(tableData1['kotCount'] == 1, 'kotCount must be 1');
    print('✅ Verified Firestore Table: status=${tableData1['status']}, kotCount=${tableData1['kotCount']}, activeOrderId=${tableData1['activeOrderId']}');

    final orderRef = firestore
        .collection('businesses')
        .doc('coffee_katta')
        .collection('branches')
        .doc('latur_main')
        .collection('orders')
        .doc(kot1.orderId);
    final orderSnap1 = await orderRef.get();
    final orderData1 = orderSnap1.data()!;
    final List<dynamic> kotIds1 = orderData1['kotIds'] ?? [];
    assert(kotIds1.contains(kot1.kotId), 'order.kotIds must contain kot1');
    print('✅ Verified Firestore Order: kotIds=$kotIds1');

    // TEST 2: Second KOT on active order (SEND & PRINT workflow)
    print('\n--- TEST 2: Executing SEND & PRINT workflow (append KOT to existing order) ---');
    final kot2 = await kotService.createKOT(
      tableId: testTableId,
      tableName: 'Diagnostic Table',
      items: [
        const KOTItem(
          uniqueId: 'test_item_send_2',
          itemId: 'DIAG_02',
          name: 'Cold Brew Latte',
          category: 'Coffee',
          qty: 1,
          price: 150.0,
        ),
      ],
      userId: 'test_forensic_agent',
      userName: 'Diagnostic Agent',
    );

    print('✅ TEST 2 PASSED: KOT #${kot2.kotNumber} created on existing order ${kot2.orderId}!');
    assert(kot2.orderId == kot1.orderId, 'Order ID must match existing order');
    assert(kot2.kotNumber == kot1.kotNumber + 1, 'KOT number must increment sequentially');

    // Verify order document has both KOT IDs appended cleanly
    final orderSnap2 = await orderRef.get();
    final List<dynamic> kotIds2 = orderSnap2.data()!['kotIds'] ?? [];
    assert(kotIds2.length == 2, 'kotIds length should be 2');
    assert(kotIds2[0] == kot1.kotId && kotIds2[1] == kot2.kotId, 'kotIds must contain both KOTs in order');
    print('✅ Verified Firestore Order after second KOT: kotIds=$kotIds2');

    // TEST 3: Test KOT byte formatting for printing
    print('\n--- TEST 3: Verifying Print formatting for KOT ---');
    final printService = PrintService();
    final bytes = await printService.generateKOTBytes(kot2, PrinterPaperSize.mm80);
    print('✅ Generated ${bytes.length} ESC/POS bytes for KOT #${kot2.kotNumber} cleanly without variant error.');

    // Test mark as printed
    await kotService.markAsPrinted(kot2.kotId, testTableId);
    final kotSnap = await firestore
        .collection('businesses')
        .doc('coffee_katta')
        .collection('branches')
        .doc('latur_main')
        .collection('kots')
        .doc(kot2.kotId)
        .get();
    assert(kotSnap.data()?['isPrinted'] == true, 'KOT must be marked printed');
    print('✅ Verified Firestore KOT markAsPrinted: isPrinted=${kotSnap.data()?['isPrinted']}');

    // Clean up test documents in Firestore
    print('\n--- CLEANUP: Removing diagnostic test documents ---');
    await tableRef.delete();
    await orderRef.delete();
    await firestore
        .collection('businesses')
        .doc('coffee_katta')
        .collection('branches')
        .doc('latur_main')
        .collection('kots')
        .doc(kot1.kotId)
        .delete();
    await firestore
        .collection('businesses')
        .doc('coffee_katta')
        .collection('branches')
        .doc('latur_main')
        .collection('kots')
        .doc(kot2.kotId)
        .delete();
    print('✅ Cleanup completed cleanly.');

    print('\n=============================================');
    print('ALL NATIVE WINDOWS FIRESTORE TESTS PASSED 100%!');
    print('=============================================');
    exit(0);
  } catch (e, stack) {
    print('❌ TEST FAILED WITH EXCEPTION: $e');
    print(stack);
    exit(1);
  }
}
