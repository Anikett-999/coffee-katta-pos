import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/table_model.dart';

class TableService {
  final FirebaseFirestore _firestore;
  final String businessId = 'coffee_katta';
  final String branchId;

  TableService({required this.branchId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference get _branchRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId);

  CollectionReference get _tableCollection => _branchRef.collection('tables');
  CollectionReference get _orderCollection => _branchRef.collection('orders');
  CollectionReference get _kotCollection => _branchRef.collection('kots');
  CollectionReference get _billCollection => _branchRef.collection('bills');

  // Stream of all tables for the current branch
  Stream<List<TableModel>> watchTables() {
    // Use incremental updates to avoid reparsing/sorting entire lists on each snapshot
    final controller = StreamController<List<TableModel>>.broadcast(onListen: () {});
    final Map<String, TableModel> cache = {};

    final sub = _tableCollection.snapshots().listen((snapshot) {
      try {
        // Apply document changes incrementally
        for (final change in snapshot.docChanges) {
          final doc = change.doc;
          final raw = doc.data() as Map<String, dynamic>?;
          if (raw == null) continue;

          final data = Map<String, dynamic>.from(raw);
          // Ensure tableId exists for parsing
          if (!data.containsKey('tableId') || (data['tableId'] as String).isEmpty) {
            data['tableId'] = doc.id;
          }
          // Convert Timestamp to ISO string if needed
          if (data['updatedAt'] is Timestamp) {
            data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
          }

          try {
            final model = TableModel.fromJson(data);
            if (change.type == DocumentChangeType.removed) {
              cache.remove(model.tableId);
            } else {
              cache[model.tableId] = model;
            }
          } catch (e) {
            // Ignore parse errors for individual docs
            continue;
          }
        }

        // Emit sorted list
        final tables = cache.values.toList();
        tables.sort((a, b) {
          final aNum = int.tryParse(RegExp(r'\d+').stringMatch(a.name) ?? '');
          final bNum = int.tryParse(RegExp(r'\d+').stringMatch(b.name) ?? '');
          if (aNum != null && bNum != null) {
            if (aNum != bNum) return aNum.compareTo(bNum);
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        controller.add(tables);
      } catch (e) {
        // If anything goes wrong, do not crash the stream
      }
    });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Create a new table (Admin only)
  Future<void> createTable(String name, int capacity) async {
    final docRef = _tableCollection.doc();
    final table = TableModel(
      tableId: docRef.id,
      name: name,
      capacity: capacity,
      updatedAt: DateTime.now(),
    );
    await docRef.set(table.toJson());
  }

  // Lock table for billing
  Future<void> lockForBilling(String tableId) async {
    final docRef = _tableCollection.doc(tableId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) throw Exception('Table not found');
    
    final data = snapshot.data() as Map<String, dynamic>;
    if (data['status'] != 'occupied') {
      throw Exception('Table must be occupied to start billing');
    }

    await docRef.update({
      'status': 'billing',
      'updatedAt': Timestamp.now(),
    });
  }

  // Update an existing table
  Future<void> updateTable(String tableId, String name, int capacity) async {
    await _tableCollection.doc(tableId).update({
      'name': name,
      'capacity': capacity,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a table (Admin only)
  Future<void> deleteTable(String tableId) async {
    final docRef = _tableCollection.doc(tableId);
    final snapshot = await docRef.get();

    if (!snapshot.exists) throw Exception('Table does not exist');

    final data = snapshot.data() as Map<String, dynamic>;
    if (data['status'] != 'available') {
      throw Exception('Cannot delete table while it is ${data['status']}');
    }

    await docRef.delete();
  }

  // Clear table after successful billing or explicit manager abandonment override
  Future<void> clearTable(
    String tableId, {
    String? abandonReason,
    String? authorizedBy,
  }) async {
    final tableRef = _tableCollection.doc(tableId);
    final tableSnap = await tableRef.get();

    if (!tableSnap.exists) {
      throw Exception('Table $tableId does not exist');
    }

    final tableData = tableSnap.data() as Map<String, dynamic>? ?? {};
    final activeOrderId = tableData['activeOrderId'] as String?;
    final double totalAmount = (tableData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final int itemCount = (tableData['itemCount'] as num?)?.toInt() ?? 0;

    if (activeOrderId != null && activeOrderId.isNotEmpty) {
      // 1. Audit Check: Check if a settled bill exists for this order
      final billSnap = await _billCollection
          .where('orderId', isEqualTo: activeOrderId)
          .limit(1)
          .get();

      final bool isBilled = billSnap.docs.isNotEmpty;

      // If table has orders/items/balance and NO bill has been generated:
      if (!isBilled && (totalAmount > 0 || itemCount > 0)) {
        // Must provide an explicit abandonment reason (min 5 chars)
        if (abandonReason == null || abandonReason.trim().length < 5) {
          throw Exception(
            'Cannot clear table: Active order $activeOrderId has not been billed (₹${totalAmount.toStringAsFixed(2)}). '
            'Please settle the bill in checkout or provide a valid manager abandonment reason (min 5 characters).',
          );
        }

        // Mark order as abandoned with audit details
        await _orderCollection.doc(activeOrderId).update({
          'status': 'abandoned',
          'abandonReason': abandonReason.trim(),
          'abandonedBy': authorizedBy ?? 'Unknown Staff',
          'closedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Table is either billed or was an empty order (0 items / 0 amount)
        await _orderCollection.doc(activeOrderId).update({
          'status': 'closed',
          'closedAt': FieldValue.serverTimestamp(),
        });
      }

      // Ensure all KOT items for this order are marked served
      final kotSnaps = await _kotCollection.where('orderId', isEqualTo: activeOrderId).get();
      if (kotSnaps.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in kotSnaps.docs) {
          final kotData = doc.data() as Map<String, dynamic>;
          final items = List<Map<String, dynamic>>.from(
            (kotData['items'] as List<dynamic>? ?? []).map((i) => Map<String, dynamic>.from(i as Map)),
          );
          bool hasChanges = false;
          for (var item in items) {
            if (item['status'] != 'served') {
              item['status'] = 'served';
              hasChanges = true;
            }
          }
          if (hasChanges) {
            batch.update(doc.reference, {'items': items});
          }
        }
        await batch.commit();
      }
    }

    await tableRef.update({
      'status': 'available',
      'activeOrderId': null,
      'totalAmount': 0.0,
      'itemCount': 0,
      'kotCount': 0,
      'unprintedKotCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
