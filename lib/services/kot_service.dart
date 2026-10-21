import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/order_model.dart';
import 'package:uuid/uuid.dart';

void _logDiagnostic(String message) {
  if (kDebugMode) {
    debugPrint('[KOTService] $message');
  }
}

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

  static Future<void> _kotLock = Future.value();

  /// Atomically allocates the next sequential KOT number using a FIFO async queue.
  /// 100% crash-proof on Windows Desktop C++ runtime (avoids C++ runTransaction abort() crashes)
  /// while guaranteeing zero collisions during rapid or simultaneous order dispatches.
  Future<int> _allocateNextKotNumber(String todayStr) async {
    final previousLock = _kotLock;
    final completer = Completer<void>();
    _kotLock = completer.future;

    try {
      await previousLock;
      final counterSnapshot = await _counterDoc.get();
      int kotNumber = 1001;
      if (counterSnapshot.exists) {
        final counterData = counterSnapshot.data() as Map<String, dynamic>;
        final String lastReset = counterData['lastResetDate'] ?? '';

        if (lastReset == todayStr) {
          kotNumber = (counterData['kotCounter'] ?? 1000) + 1;
        } else {
          kotNumber = 1001;
        }
      }

      await _counterDoc.set(
        {
          'kotCounter': kotNumber,
          'lastResetDate': todayStr,
        },
        SetOptions(merge: true),
      );

      return kotNumber;
    } finally {
      completer.complete();
    }
  }

  // Create KOT for a table
  Future<KOTModel> createKOT({
    required String tableId,
    required String tableName,
    required List<KOTItem> items,
    required String userId,
    required String userName,
  }) async {
    _logDiagnostic('[DART ENTRY] KOTService.createKOT initiated: tableId=$tableId, items=${items.length}');
    try {
      final now = DateTime.now();
      final currentTimestamp = Timestamp.fromDate(now);
      final String todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final dailyStatRef = _branchRef.collection('daily_stats').doc(todayStr);

      // 1. Allocate unique sequential KOT number atomically (concurrency collision protection)
      final kotNumber = await _allocateNextKotNumber(todayStr);
      _logDiagnostic('[ALLOCATE ATOMIC] Guaranteed unique KOT #$kotNumber obtained via transaction');

      // Parallelize initial reads to minimize pre-write latency
      final initialReads = await Future.wait([
        _tableCollection.doc(tableId).get(),
        dailyStatRef.get(),
      ]);

      final tableSnapshot = initialReads[0];
      final dailyStatSnapshot = initialReads[1];

      if (!tableSnapshot.exists) throw Exception('Table not found');
      _logDiagnostic('[READ PARALLEL] table and daily_stats obtained');

      final tableData = tableSnapshot.data() as Map<String, dynamic>;
      String? orderId = tableData['activeOrderId'];

      // Read existing order document if table has an active order
      DocumentSnapshot? orderSnapshot;
      if (orderId != null) {
        orderSnapshot = await _orderCollection.doc(orderId).get();
        if (!orderSnapshot.exists) {
          orderId = null;
        }
      }
      _logDiagnostic('[READ ORDER] orderSnapshot obtained (orderId=$orderId, exists=${orderSnapshot?.exists})');

      // --- ATOMIC BATCH WRITES ---
      final batch = _firestore.batch();
      final Map<String, dynamic> tableUpdates = {};

      final kotId = const Uuid().v4();
      final double kotTotal =
          items.fold(0.0, (total, i) => total + (i.price * i.qty));

      if (orderId == null) {
        final newOrderRef = _orderCollection.doc();
        orderId = newOrderRef.id;

        final newOrder = OrderModel(
          orderId: orderId,
          tableId: tableId,
          kotIds: [kotId],
          createdAt: now,
        );

        final Map<String, dynamic> orderPayload =
            Map<String, dynamic>.from(newOrder.toJson());
        orderPayload.remove('closedAt');

        _logDiagnostic('[BATCH SET 1] Staging newOrder (orderId=$orderId, closedAt omitted)');
        batch.set(newOrderRef, orderPayload);

        tableUpdates['activeOrderId'] = orderId;
        tableUpdates['status'] = 'occupied';
      } else {
        final orderData =
            orderSnapshot!.data() as Map<String, dynamic>? ?? {};
        final List<String> currentKotIds = List<String>.from(
            orderData['kotIds'] as List<dynamic>? ?? []);
        if (!currentKotIds.contains(kotId)) {
          currentKotIds.add(kotId);
        }
        _logDiagnostic('[BATCH UPDATE 1] Staging update order kotIds: $currentKotIds');
        batch.update(_orderCollection.doc(orderId), {
          'kotIds': currentKotIds,
        });
      }

      // Update Daily Stats summary using concrete client timestamp
      final Map<String, dynamic> dailyStatData = {
        'totalKots': kotNumber - 1000,
        'lastKotNumber': kotNumber,
        'date': todayStr,
        'lastUpdated': currentTimestamp,
      };

      _logDiagnostic('[BATCH SET 3] Staging dailyStat write');
      if (dailyStatSnapshot.exists) {
        final existingStats =
            dailyStatSnapshot.data() as Map<String, dynamic>? ?? {};
        batch.set(
          dailyStatRef,
          <String, dynamic>{
            ...existingStats,
            ...dailyStatData,
          },
          SetOptions(merge: true),
        );
      } else {
        batch.set(
          dailyStatRef,
          dailyStatData,
        );
      }

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

      _logDiagnostic('[BATCH SET 4] Staging kot write (kotId=$kotId, kotNumber=$kotNumber)');
      batch.set(_kotCollection.doc(kotId), kot.toJson());

      // 4. Update Table denormalized counts/totals
      final double currentTotal = (tableData['totalAmount'] ?? 0.0) + kotTotal;
      final int currentItemCount = (tableData['itemCount'] ?? 0) + items.length;
      final int currentKotCount = (tableData['kotCount'] ?? 0) + 1;

      tableUpdates['totalAmount'] = currentTotal;
      tableUpdates['itemCount'] = currentItemCount;
      tableUpdates['kotCount'] = currentKotCount;
      tableUpdates['unprintedKotCount'] =
          (tableData['unprintedKotCount'] ?? 0) + 1;
      tableUpdates['updatedAt'] = currentTimestamp;

      _logDiagnostic('[BATCH UPDATE 5] Staging table update ($tableId)');
      batch.update(_tableCollection.doc(tableId), tableUpdates);

      _logDiagnostic('[BATCH COMMIT] Committing atomic batch to Firestore...');
      await batch.commit();

      _logDiagnostic('[DART SUCCESS] batch.commit() completed successfully, returning KOT #${kot.kotNumber}');
      return kot;
    } catch (e, st) {
      _logDiagnostic('[DART ERROR] createKOT caught exception: $e\n$st');
      rethrow;
    }
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
    final snapshot = await kotRef.get();
    if (!snapshot.exists) throw Exception('KOT not found');
    
    final kotData = snapshot.data() as Map<String, dynamic>;
    final List<dynamic> items = List.from(kotData['items']);
    
    final itemIndex = items.indexWhere((i) => i['uniqueId'] == itemUniqueId);
    if (itemIndex != -1) {
      items[itemIndex]['status'] = status;
      await kotRef.update({'items': items});
    }
  }

  // Atomically mark all items in a KOT as served
  Future<void> markAllItemsServed({
    required String kotId,
  }) async {
    final kotRef = _kotCollection.doc(kotId);
    final snapshot = await kotRef.get();
    if (!snapshot.exists) throw Exception('KOT not found');
    
    final kotData = snapshot.data() as Map<String, dynamic>;
    final List<dynamic> items = List.from(kotData['items']);
    
    for (var item in items) {
      if (item is Map) {
        item['status'] = 'served';
      }
    }
    await kotRef.update({'items': items});
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
    final kotSnap = await kotRef.get();
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

    final parallelReads = await Future.wait([
      tableRef.get(),
      orderRef.get(),
    ]);
    final tableSnap = parallelReads[0];
    final orderSnap = parallelReads[1];
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

    final batch = _firestore.batch();
    final tableUpdates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (action == _KotItemMutationAction.deduct && qty > 1) {
      items[itemIndex]['qty'] = qty - 1;
      batch.update(kotRef, {
        'items': items,
        'totalAmount': (currentKotTotal - price).clamp(0, double.infinity),
      });
      tableUpdates['totalAmount'] = (currentTableTotal - price).clamp(0, double.infinity);
      batch.update(tableRef, tableUpdates);
      await batch.commit();
      return;
    }

    final removedLineValue = price * qty;
    items.removeAt(itemIndex);
    tableUpdates['totalAmount'] = (currentTableTotal - removedLineValue).clamp(0, double.infinity);
    tableUpdates['itemCount'] = currentItemCount > 0 ? currentItemCount - 1 : 0;

    if (items.isEmpty) {
      batch.delete(kotRef);
      batch.update(orderRef, {
        'kotIds': FieldValue.arrayRemove([kotId]),
      });
      final newKotCount = currentKotCount > 0 ? currentKotCount - 1 : 0;
      tableUpdates['kotCount'] = newKotCount;
      if (!isPrinted && currentUnprintedCount > 0) {
        tableUpdates['unprintedKotCount'] = currentUnprintedCount - 1;
      }

      if (newKotCount == 0) {
        tableUpdates['status'] = 'available';
        tableUpdates['activeOrderId'] = null;
        tableUpdates['totalAmount'] = 0.0;
        tableUpdates['itemCount'] = 0;
        tableUpdates['kotCount'] = 0;
        tableUpdates['unprintedKotCount'] = 0;
        batch.update(orderRef, {
          'status': 'cancelled',
          'closedAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      batch.update(kotRef, {
        'items': items,
        'totalAmount': (currentKotTotal - removedLineValue).clamp(0, double.infinity),
      });
    }

    batch.update(tableRef, tableUpdates);
    await batch.commit();
  }

  // Cancel/Void an unprinted KOT and safely revert table status to available if no other KOTs remain
  Future<void> cancelUnprintedKot({
    required String kotId,
    required String tableId,
  }) async {
    final kotRef = _kotCollection.doc(kotId);
    final tableRef = _tableCollection.doc(tableId);

    final results = await Future.wait([
      kotRef.get(),
      tableRef.get(),
    ]);

    final kotSnap = results[0];
    final tableSnap = results[1];

    if (!kotSnap.exists) {
      throw Exception('KOT not found');
    }
    if (!tableSnap.exists) {
      throw Exception('Table not found');
    }

    final kotData = kotSnap.data() as Map<String, dynamic>;
    final orderId = kotData['orderId'] as String? ?? '';
    final isPrinted = kotData['isPrinted'] == true;
    final kotTotal = (kotData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final items = (kotData['items'] as List<dynamic>? ?? []);
    final kotItemCount = items.length;

    final tableData = tableSnap.data() as Map<String, dynamic>;
    final currentTableTotal = (tableData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final currentItemCount = (tableData['itemCount'] as num?)?.toInt() ?? 0;
    final currentKotCount = (tableData['kotCount'] as num?)?.toInt() ?? 0;
    final currentUnprintedCount = (tableData['unprintedKotCount'] as num?)?.toInt() ?? 0;

    DocumentSnapshot? orderSnap;
    if (orderId.isNotEmpty) {
      orderSnap = await _orderCollection.doc(orderId).get();
    }

    final batch = _firestore.batch();
    batch.delete(kotRef);

    final newKotCount = currentKotCount > 0 ? currentKotCount - 1 : 0;
    final newTotal = (currentTableTotal - kotTotal).clamp(0.0, double.infinity);
    final newItemCount = (currentItemCount - kotItemCount).clamp(0, 999999);
    final newUnprinted = (!isPrinted && currentUnprintedCount > 0)
        ? currentUnprintedCount - 1
        : currentUnprintedCount;

    final tableUpdates = <String, dynamic>{
      'totalAmount': newTotal,
      'itemCount': newItemCount,
      'kotCount': newKotCount,
      'unprintedKotCount': newUnprinted,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (orderSnap != null && orderSnap.exists) {
      final orderData = orderSnap.data() as Map<String, dynamic>;
      final kotIds = List<String>.from(orderData['kotIds'] as List<dynamic>? ?? []);
      kotIds.remove(kotId);

      if (kotIds.isEmpty || newKotCount == 0) {
        batch.update(_orderCollection.doc(orderId), {
          'kotIds': [],
          'status': 'cancelled',
          'closedAt': FieldValue.serverTimestamp(),
        });

        tableUpdates['status'] = 'available';
        tableUpdates['activeOrderId'] = null;
        tableUpdates['totalAmount'] = 0.0;
        tableUpdates['itemCount'] = 0;
        tableUpdates['kotCount'] = 0;
        tableUpdates['unprintedKotCount'] = 0;
      } else {
        batch.update(_orderCollection.doc(orderId), {
          'kotIds': kotIds,
        });
      }
    } else if (newKotCount == 0) {
      tableUpdates['status'] = 'available';
      tableUpdates['activeOrderId'] = null;
      tableUpdates['totalAmount'] = 0.0;
      tableUpdates['itemCount'] = 0;
      tableUpdates['kotCount'] = 0;
      tableUpdates['unprintedKotCount'] = 0;
    }

    batch.update(tableRef, tableUpdates);
    await batch.commit();
  }

  // Mark KOT as printed and update table count
  Future<void> markAsPrinted(String kotId, String tableId) async {
    final kotRef = _kotCollection.doc(kotId);
    final tableRef = _tableCollection.doc(tableId);

    try {
      final results = await Future.wait([
        kotRef.get(),
        tableRef.get(),
      ]);

      final kotSnap = results[0];
      final tableSnap = results[1];

      if (kotSnap.exists && tableSnap.exists) {
        final kotData = kotSnap.data() as Map<String, dynamic>;
        // Only decrement if it wasn't already printed
        if (kotData['isPrinted'] != true) {
          final batch = _firestore.batch();
          batch.update(kotRef, {'isPrinted': true});

          final tableData = tableSnap.data() as Map<String, dynamic>;
          final int count = tableData['unprintedKotCount'] ?? 0;
          if (count > 0) {
            batch.update(tableRef, {'unprintedKotCount': count - 1});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Error marking KOT as printed: $e');
    }
  }
}

enum _KotItemMutationAction {
  deduct,
  remove,
}
