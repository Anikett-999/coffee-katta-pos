import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/bill_model.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/table_model.dart';
import 'analytics_service.dart';

class BillingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String businessId = 'coffee_katta';
  final String branchId;
  final AnalyticsService _analyticsService = AnalyticsService();

  BillingService({required this.branchId});

  DocumentReference get _branchRef => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('branches')
      .doc(branchId);

  CollectionReference get _billCollection => _branchRef.collection('bills');
  CollectionReference get _kotCollection => _branchRef.collection('kots');
  CollectionReference get _orderCollection => _branchRef.collection('orders');
  CollectionReference get _tableCollection => _branchRef.collection('tables');
  DocumentReference get _counterDoc => _branchRef.collection('counters').doc('global');

  List<BillItem> _aggregateKOTItems(List<KOTModel> kots) {
    Map<String, BillItem> aggregatedMap = {};

    for (var kot in kots) {
      for (var item in kot.items) {
        if (item.status != 'rejected') {
          if (aggregatedMap.containsKey(item.name)) {
            final existing = aggregatedMap[item.name]!;
            aggregatedMap[item.name] = existing.copyWith(
              qty: existing.qty + item.qty,
            );
          } else {
            aggregatedMap[item.name] = BillItem(
              name: item.name,
              category: item.category,
              qty: item.qty,
              price: item.price,
              note: item.note,
            );
          }
        }
      }
    }

    return aggregatedMap.values.toList();
  }

  // Preview Bill (Aggregates all KOTs for an order)
  Future<Map<String, dynamic>> previewBill(String orderId) async {
    final kotSnapshots = await _kotCollection.where('orderId', isEqualTo: orderId).get();
    final kots = kotSnapshots.docs.map((doc) => KOTModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

    final billItems = _aggregateKOTItems(kots);
    double subtotal = 0.0;
    for (var item in billItems) {
      subtotal += (item.price * item.qty);
    }

    return {
      'items': billItems,
      'subtotal': subtotal,
      'kots': kots, // Added for the KOT history panel
    };
  }

  // Generate Final Bill
  Future<BillModel> generateBill({
    required String orderId,
    required String tableId,
    required String tableName,
    required String userName,
    required double discountValue,
    String discountType = 'percent',
    required double extraCharges,
    required List<Payment> payments,
    required String userId,
  }) async {
    // Idempotency guard: if a bill already exists for this order, return it
    final existing = await _billCollection.where('orderId', isEqualTo: orderId).limit(1).get();
    if (existing.docs.isNotEmpty) {
      final data = existing.docs.first.data() as Map<String, dynamic>;
      return BillModel.fromJson(data);
    }

    return await _firestore.runTransaction((transaction) async {
      // 1. Lock table for billing
      final tableRef = _tableCollection.doc(tableId);
      final tableSnap = await transaction.get(tableRef);
      if (!tableSnap.exists) throw Exception('Table not found');
      
      final tableData = TableModel.fromJson(tableSnap.data() as Map<String, dynamic>);
      if (tableData.status != 'occupied' && tableData.status != 'billing') {
        throw Exception('Invalid table status for billing');
      }

      // 2. Aggregate items
      final kotSnapshots = await _kotCollection.where('orderId', isEqualTo: orderId).get();
      final kots = kotSnapshots.docs.map((doc) => KOTModel.fromJson(doc.data() as Map<String, dynamic>)).toList();

      final billItems = _aggregateKOTItems(kots);
      double subtotal = 0.0;
      for (var item in billItems) {
        subtotal += (item.price * item.qty);
      }

      // 3. Validate & Apply calculations
      // Guard: reject negative inputs
      if (discountValue < 0) throw Exception('Discount value cannot be negative');
      if (extraCharges < 0) throw Exception('Extra charges cannot be negative');

      double discountAmount;
      double discountPercent;
      if (discountType == 'flat') {
        // Clamp flat discount: cannot exceed subtotal
        discountAmount = discountValue.clamp(0, subtotal);
        discountPercent = 0.0;
      } else {
        // Clamp percentage: 0-100%
        discountPercent = discountValue.clamp(0, 100);
        discountAmount = (subtotal * discountPercent) / 100;
      }
      double total = (subtotal - discountAmount) + extraCharges;
      // Final safety net: total must never be negative
      if (total < 0) total = 0;

      // 4. Fetch/Calculate Bill ID with Daily Reset (Start from 1001)
      final now = DateTime.now();
      final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final counterSnap = await transaction.get(_counterDoc);
      int billNumber = 1001;
      
      if (counterSnap.exists) {
        final counterData = counterSnap.data() as Map<String, dynamic>;
        final String lastReset = counterData['lastBillResetDate'] ?? '';
        
        if (lastReset == todayStr) {
          billNumber = (counterData['billCounter'] ?? 1000) + 1;
        }
      }

      // Update counters (Global)
      transaction.set(_counterDoc, {
        'billCounter': billNumber,
        'lastBillResetDate': todayStr,
      }, SetOptions(merge: true));

      final String billId = "INV-${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${billNumber.toString().substring(1)}";
      
      final bill = BillModel(
        billId: billId,
        orderId: orderId,
        tableId: tableId,
        tableName: tableName,
        userName: userName,
        items: billItems,
        subtotal: subtotal,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        discountType: discountType,
        extraCharges: extraCharges,
        total: total,
        payments: payments,
        createdAt: DateTime.now(),
        createdBy: userId,
      );

      transaction.set(_billCollection.doc(billId), bill.toJson());

      transaction.update(tableRef, {
        'status': 'billing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Automatically assume all KOT items as served once invoice/bill is generated
      for (final kotDoc in kotSnapshots.docs) {
        final kotData = kotDoc.data() as Map<String, dynamic>;
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
          transaction.update(kotDoc.reference, {'items': items});
        }
      }

      // Update Analytics (Async Fire-and-Forget for performance)
      _analyticsService.updateDailyAnalytics(bill, branchId);

      return bill;
    });
  }

  // Finalize and Clear Table
  Future<void> finalizeAndClearTable(String tableId, String orderId) async {
    // 1. Fetch any KOTs for this order to ensure all items are marked served
    final kotSnapshots = await _kotCollection.where('orderId', isEqualTo: orderId).get();

    await _firestore.runTransaction((transaction) async {
      // 2. Close Order
      transaction.update(_orderCollection.doc(orderId), {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });

      // 3. Clear Table
      transaction.update(_tableCollection.doc(tableId), {
        'status': 'available',
        'activeOrderId': null,
        'totalAmount': 0.0,
        'itemCount': 0,
        'kotCount': 0,
        'unprintedKotCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 4. Mark any remaining KOT items as served
      for (final doc in kotSnapshots.docs) {
        final kotData = doc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(
          (kotData['items'] as List<dynamic>? ?? []).map((item) => Map<String, dynamic>.from(item as Map)),
        );
        bool hasChanges = false;
        for (var item in items) {
          if (item['status'] != 'served') {
            item['status'] = 'served';
            hasChanges = true;
          }
        }
        if (hasChanges) {
          transaction.update(doc.reference, {'items': items});
        }
      }
    });
  }

  // Void an existing bill with audit logging, optional table restoration, and analytics reversal
  Future<BillModel> voidBill({
    required String billId,
    required String voidedBy,
    required String voidReason,
    bool restoreTable = false,
  }) async {
    if (voidReason.trim().length < 3) {
      throw Exception('A valid reason (minimum 3 characters) is required to void a bill.');
    }

    final billDocRef = _billCollection.doc(billId);

    final updatedBill = await _firestore.runTransaction((transaction) async {
      // ═════════════════════════════════════════════════════════════════════
      // PHASE 1: ALL READS FIRST (Strict Firestore Transaction Invariant)
      // ═════════════════════════════════════════════════════════════════════
      final billSnap = await transaction.get(billDocRef);
      if (!billSnap.exists) {
        throw Exception('Bill $billId does not exist.');
      }

      final billData = Map<String, dynamic>.from(billSnap.data() as Map);
      if (billData['isVoided'] == true) {
        throw Exception('Bill $billId is already voided.');
      }

      final tableId = billData['tableId'] as String?;
      final orderId = billData['orderId'] as String?;

      final now = DateTime.now();

      // Guard: Only allow table restoration if the bill was created TODAY and within the last 3 hours
      DateTime billCreatedAt = now;
      final rawCreatedAt = billData['createdAt'];
      if (rawCreatedAt is Timestamp) {
        billCreatedAt = rawCreatedAt.toDate();
      } else if (rawCreatedAt is DateTime) {
        billCreatedAt = rawCreatedAt;
      } else if (rawCreatedAt is String) {
        billCreatedAt = DateTime.tryParse(rawCreatedAt) ?? now;
      }

      final isSameDay = billCreatedAt.year == now.year &&
          billCreatedAt.month == now.month &&
          billCreatedAt.day == now.day;
      final isRecent = now.difference(billCreatedAt).inHours < 3;
      final shouldRestoreTable = restoreTable && isSameDay && isRecent;

      DocumentReference? tableRef;
      DocumentSnapshot? tableSnap;
      DocumentReference? orderRef;
      DocumentSnapshot? orderSnap;

      // Read table and order BEFORE ANY WRITES are executed
      if (shouldRestoreTable && tableId != null && orderId != null) {
        tableRef = _tableCollection.doc(tableId);
        tableSnap = await transaction.get(tableRef);

        orderRef = _orderCollection.doc(orderId);
        orderSnap = await transaction.get(orderRef);
      }

      // ═════════════════════════════════════════════════════════════════════
      // PHASE 2: ALL WRITES AFTER ALL READS
      // ═════════════════════════════════════════════════════════════════════

      // 1. Mark bill as voided
      transaction.update(billDocRef, {
        'isVoided': true,
        'voidedAt': FieldValue.serverTimestamp(),
        'voidedBy': voidedBy,
        'voidReason': voidReason.trim(),
        'tableRestored': shouldRestoreTable,
      });

      // 2. Optionally restore table and order so staff can re-bill / fix mistakes
      if (shouldRestoreTable && tableRef != null && tableSnap != null && tableSnap.exists) {
        final tableData = tableSnap.data() as Map<String, dynamic>? ?? {};
        final currentStatus = tableData['status'] as String? ?? 'available';

        // If table is available or billing, restore it to occupied
        if (currentStatus == 'available' || currentStatus == 'billing') {
          final billTotal = (billData['total'] as num?)?.toDouble() ?? 0.0;
          final itemsList = billData['items'] as List<dynamic>? ?? [];
          final totalItemQty = itemsList.fold<int>(
            0,
            (totalQty, i) => totalQty + ((i['qty'] as num?)?.toInt() ?? 1),
          );

          transaction.update(tableRef, {
            'status': 'occupied',
            'activeOrderId': orderId,
            'totalAmount': billTotal,
            'itemCount': totalItemQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Re-open order
      if (shouldRestoreTable && orderRef != null && orderSnap != null && orderSnap.exists) {
        transaction.update(orderRef, {
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      billData['isVoided'] = true;
      billData['voidedAt'] = now;
      billData['voidedBy'] = voidedBy;
      billData['voidReason'] = voidReason.trim();
      billData['tableRestored'] = shouldRestoreTable;

      return BillModel.fromJson(billData);
    });

    // 3. Reverse Analytics
    await _analyticsService.reverseDailyAnalytics(updatedBill, branchId);

    return updatedBill;
  }
}
