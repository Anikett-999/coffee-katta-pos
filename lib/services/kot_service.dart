import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/order_model.dart';
import 'package:uuid/uuid.dart';

class KOTService {
  final FirebaseFirestore _firestore;
  final String businessId = 'coffee_katta';
  final String branchId;

  // Make branchId optional for tests; production code should pass explicit branchId.
  KOTService({FirebaseFirestore? firestore, String? branchId})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        branchId = branchId ?? 'latur_main';

  DocumentReference get _branchRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId);

  CollectionReference get _kotCollection => _branchRef.collection('kots');
  CollectionReference get _orderCollection => _branchRef.collection('orders');
  CollectionReference get _tableCollection => _branchRef.collection('tables');
  DocumentReference get _counterDoc => _branchRef.collection('counters').doc('global');

  // Create KOT for a table
  Future<KOTModel> createKOT({
    required String tableId,
    required String tableName,
    required List<KOTItem> items,
    required String userId,
    required String userName,
  }) async {
    return await _firestore.runTransaction((transaction) async {
      // --- READS (All reads MUST happen before any writes) ---
      // 1. Get active order for table
      final tableSnapshot = await transaction.get(_tableCollection.doc(tableId));
      if (!tableSnapshot.exists) throw Exception('Table not found');

      // 2. Get global KOT counter
      final counterSnapshot = await transaction.get(_counterDoc);
      
      // --- WRITES ---
      final tableData = tableSnapshot.data() as Map<String, dynamic>;
      String? orderId = tableData['activeOrderId'];

      final Map<String, dynamic> tableUpdates = {};

      final kotId = const Uuid().v4();
      final double kotTotal = items.fold(0.0, (total, i) => total + (i.price * i.qty));

      if (orderId == null) {
        final newOrderRef = _orderCollection.doc();
        orderId = newOrderRef.id;

        final newOrder = OrderModel(
          orderId: orderId,
          tableId: tableId,
          kotIds: [kotId],
          createdAt: DateTime.now(),
        );

        transaction.set(newOrderRef, newOrder.toJson());
        
        tableUpdates['activeOrderId'] = orderId;
        tableUpdates['status'] = 'occupied';
      } else {
        transaction.update(_orderCollection.doc(orderId), {
          'kotIds': FieldValue.arrayUnion([kotId]),
        });
      }

      // 2. Fetch/Calculate KOT number with Daily Reset (Start from 1001)
      final now = DateTime.now();
      final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      int kotNumber = 1001;
      if (counterSnapshot.exists) {
        final counterData = counterSnapshot.data() as Map<String, dynamic>;
        final String lastReset = counterData['lastResetDate'] ?? '';
        
        if (lastReset == todayStr) {
          kotNumber = (counterData['kotCounter'] ?? 1000) + 1;
        } else {
          // New day reset
          kotNumber = 1001;
        }
      }

      // Update counters (Global)
      transaction.set(_counterDoc, {
        'kotCounter': kotNumber,
        'lastResetDate': todayStr,
      });

      // Update Daily Stats summary
      final dailyStatRef = _branchRef.collection('daily_stats').doc(todayStr);
      transaction.set(dailyStatRef, {
        'totalKots': kotNumber - 1000, // actual count of the day
        'lastKotNumber': kotNumber,
        'date': todayStr,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Create KOT document
      final kot = KOTModel(
        kotId: kotId,
        kotNumber: kotNumber,
        orderId: orderId,
        tableId: tableId,
        tableName: tableName,
        items: items,
        totalAmount: kotTotal,
        createdBy: userId,
        userName: userName,
        createdAt: now,
      );

      transaction.set(_kotCollection.doc(kotId), kot.toJson());

      // 4. Update Table denormalized counts/totals
      final double currentTotal = (tableData['totalAmount'] ?? 0.0) + kotTotal;
      final int currentItemCount = (tableData['itemCount'] ?? 0) + items.length;
      final int currentKotCount = (tableData['kotCount'] ?? 0) + 1;

      tableUpdates['totalAmount'] = currentTotal;
      tableUpdates['itemCount'] = currentItemCount;
      tableUpdates['kotCount'] = currentKotCount;
      tableUpdates['unprintedKotCount'] = (tableData['unprintedKotCount'] ?? 0) + 1;
      tableUpdates['updatedAt'] = FieldValue.serverTimestamp();

      transaction.update(_tableCollection.doc(tableId), tableUpdates);

      return kot;
    });
  }

  // Watch KOTs for a specific order
  Stream<List<KOTModel>> watchKOTsByOrder(String orderId) {
    return _kotCollection
        .where('orderId', isEqualTo: orderId)
        // .orderBy('createdAt', descending: true) // Using client-side sort as failsafe
        .snapshots()
        .map((snapshot) {
      final List<KOTModel> kots = [];
      for (var doc in snapshot.docs) {
        try {
          kots.add(KOTModel.fromJson(doc.data() as Map<String, dynamic>));
        } catch (e) {
          // Skipping corrupted KOT
        }
      }
      // Client-side sort by createdAt descending
      kots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return kots;
    });
  }

  // Watch all active KOTs for a branch (live KOT screen)
  Stream<List<KOTModel>> watchLiveKOTs() {
    return _kotCollection
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final List<KOTModel> kots = [];
      for (var doc in snapshot.docs) {
        try {
          kots.add(KOTModel.fromJson(doc.data() as Map<String, dynamic>));
        } catch (e) {
          // Skipping corrupted KOT
        }
      }
      return kots;
    });
  }

  // Update status of a specific item in a KOT
  Future<void> updateItemStatus({
    required String kotId,
    required String itemUniqueId,
    required String status,
  }) async {
    final kotRef = _kotCollection.doc(kotId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(kotRef);
      if (!snapshot.exists) throw Exception('KOT not found');
      
      final kotData = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> items = List.from(kotData['items']);
      
      final itemIndex = items.indexWhere((i) => i['uniqueId'] == itemUniqueId);
      if (itemIndex != -1) {
        items[itemIndex]['status'] = status;
        transaction.update(kotRef, {'items': items});
      }
    });
  }

  // Atomically mark all items in a KOT as served
  Future<void> markAllItemsServed({
    required String kotId,
  }) async {
    final kotRef = _kotCollection.doc(kotId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(kotRef);
      if (!snapshot.exists) throw Exception('KOT not found');
      
      final kotData = snapshot.data() as Map<String, dynamic>;
      final List<dynamic> items = List.from(kotData['items']);
      
      for (var item in items) {
        if (item is Map) {
          item['status'] = 'served';
        }
      }
      transaction.update(kotRef, {'items': items});
    });
  }

  Future<void> deductKotItem({
    required String kotId,
    required String itemUniqueId,
  }) async {
    await _mutateKotItem(
      kotId: kotId,
      itemUniqueId: itemUniqueId,
      action: _KotItemMutationAction.deduct,
    );
  }

  Future<void> removeKotItem({
    required String kotId,
    required String itemUniqueId,
  }) async {
    await _mutateKotItem(
      kotId: kotId,
      itemUniqueId: itemUniqueId,
      action: _KotItemMutationAction.remove,
    );
  }

  Future<void> _mutateKotItem({
    required String kotId,
    required String itemUniqueId,
    required _KotItemMutationAction action,
  }) async {
    final kotRef = _kotCollection.doc(kotId);

    await _firestore.runTransaction((transaction) async {
      final kotSnap = await transaction.get(kotRef);
      if (!kotSnap.exists) {
        throw Exception('KOT not found');
      }

      final kotData = kotSnap.data() as Map<String, dynamic>;
      final orderId = kotData['orderId'] as String? ?? '';
      final tableId = kotData['tableId'] as String? ?? '';
      if (orderId.isEmpty || tableId.isEmpty) {
        throw Exception('KOT is missing order or table linkage');
      }

      final tableRef = _tableCollection.doc(tableId);
      final orderRef = _orderCollection.doc(orderId);

      final tableSnap = await transaction.get(tableRef);
      final orderSnap = await transaction.get(orderRef);
      if (!tableSnap.exists || !orderSnap.exists) {
        throw Exception('Linked order/table not found');
      }

      final tableData = tableSnap.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
        (kotData['items'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)),
      );

      final itemIndex = items.indexWhere((item) => item['uniqueId'] == itemUniqueId);
      if (itemIndex == -1) {
        throw Exception('KOT item not found');
      }

      final item = items[itemIndex];
      final qty = (item['qty'] as num?)?.toInt() ?? 0;
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      if (qty <= 0) {
        throw Exception('Invalid KOT quantity');
      }

      final currentTableTotal = (tableData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final currentItemCount = (tableData['itemCount'] as num?)?.toInt() ?? 0;
      final currentKotCount = (tableData['kotCount'] as num?)?.toInt() ?? 0;
      final currentUnprintedCount = (tableData['unprintedKotCount'] as num?)?.toInt() ?? 0;
      final currentKotTotal = (kotData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final isPrinted = kotData['isPrinted'] == true;

      final tableUpdates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (action == _KotItemMutationAction.deduct && qty > 1) {
        items[itemIndex]['qty'] = qty - 1;
        transaction.update(kotRef, {
          'items': items,
          'totalAmount': (currentKotTotal - price).clamp(0, double.infinity),
        });
        tableUpdates['totalAmount'] = (currentTableTotal - price).clamp(0, double.infinity);
        transaction.update(tableRef, tableUpdates);
        return;
      }

      final removedLineValue = price * qty;
      items.removeAt(itemIndex);
      tableUpdates['totalAmount'] = (currentTableTotal - removedLineValue).clamp(0, double.infinity);
      tableUpdates['itemCount'] = currentItemCount > 0 ? currentItemCount - 1 : 0;

      if (items.isEmpty) {
        transaction.delete(kotRef);
        transaction.update(orderRef, {
          'kotIds': FieldValue.arrayRemove([kotId]),
        });
        tableUpdates['kotCount'] = currentKotCount > 0 ? currentKotCount - 1 : 0;
        if (!isPrinted && currentUnprintedCount > 0) {
          tableUpdates['unprintedKotCount'] = currentUnprintedCount - 1;
        }
      } else {
        transaction.update(kotRef, {
          'items': items,
          'totalAmount': (currentKotTotal - removedLineValue).clamp(0, double.infinity),
        });
      }

      transaction.update(tableRef, tableUpdates);
    });
  }

  // Mark KOT as printed and update table count
  Future<void> markAsPrinted(String kotId, String tableId) async {
    final kotRef = _kotCollection.doc(kotId);
    final tableRef = _tableCollection.doc(tableId);

    await _firestore.runTransaction((transaction) async {
      final kotSnap = await transaction.get(kotRef);
      final tableSnap = await transaction.get(tableRef);

      if (kotSnap.exists && tableSnap.exists) {
        final kotData = kotSnap.data() as Map<String, dynamic>;
        // Only decrement if it wasn't already printed
        if (kotData['isPrinted'] != true) {
          transaction.update(kotRef, {'isPrinted': true});
          
          final tableData = tableSnap.data() as Map<String, dynamic>;
          final int count = tableData['unprintedKotCount'] ?? 0;
          if (count > 0) {
            transaction.update(tableRef, {'unprintedKotCount': count - 1});
          }
        }
      }
    });
  }
}

enum _KotItemMutationAction {
  deduct,
  remove,
}
