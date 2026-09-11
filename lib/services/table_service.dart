import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/table_model.dart';

class TableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String businessId = 'coffee_katta';
  final String branchId;

  TableService({required this.branchId});

  CollectionReference get _tableCollection => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId)
      .collection('tables');

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
    await _firestore.runTransaction((transaction) async {
      final docRef = _tableCollection.doc(tableId);
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) throw Exception('Table not found');
      
      final data = snapshot.data() as Map<String, dynamic>;
      if (data['status'] != 'occupied') {
        throw Exception('Table must be occupied to start billing');
      }

      transaction.update(docRef, {
        'status': 'billing',
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

  // Clear table after successful billing
  Future<void> clearTable(String tableId) async {
    await _tableCollection.doc(tableId).update({
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
