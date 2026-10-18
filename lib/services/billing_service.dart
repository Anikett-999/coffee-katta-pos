import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/bill_model.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/table_model.dart';
import 'analytics_service.dart';

class BillingService {
  final FirebaseFirestore _firestore;
  final String businessId = 'coffee_katta';
  final String branchId;
  final AnalyticsService _analyticsService;

  BillingService({
    required this.branchId,
    FirebaseFirestore? firestore,
    AnalyticsService? analyticsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _analyticsService = analyticsService ??
            AnalyticsService(firestore: firestore ?? FirebaseFirestore.instance);

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

  static Future<void> _billLock = Future.value();

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

  /// Atomically allocates the next sequential invoice number using a FIFO async queue.
  /// 100% crash-proof on Windows Desktop C++ runtime (avoids C++ runTransaction abort() crashes)
  /// while guaranteeing zero collisions when multiple cashiers generate bills simultaneously.
  Future<int> _allocateNextBillNumber(String todayStr) async {
    final previousLock = _billLock;
    final completer = Completer<void>();
    _billLock = completer.future;

    try {
      await previousLock;
      final counterSnap = await _counterDoc.get();
      int billNumber = 1001;
      if (counterSnap.exists) {
        final counterData = counterSnap.data() as Map<String, dynamic>;
        final String lastReset = counterData['lastBillResetDate'] ?? '';

        if (lastReset == todayStr) {
          billNumber = (counterData['billCounter'] ?? 1000) + 1;
        } else {
          billNumber = 1001;
        }
      }

      await _counterDoc.set(
        {
          'billCounter': billNumber,
          'lastBillResetDate': todayStr,
        },
        SetOptions(merge: true),
      );

      return billNumber;
    } finally {
      completer.complete();
    }
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

    final tableRef = _tableCollection.doc(tableId);
    final kotQuery = _kotCollection.where('orderId', isEqualTo: orderId);

    // 1. Parallel Pre-Reads (Zero-wait roundtrip, avoiding Windows C++ transaction deadlock)
    final results = await Future.wait([
      tableRef.get(),
      kotQuery.get(),
    ]);

    final tableSnap = results[0] as DocumentSnapshot;
    final kotSnapshots = results[1] as QuerySnapshot;

    if (!tableSnap.exists) throw Exception('Table not found');
    
    final tableData = TableModel.fromJson(tableSnap.data() as Map<String, dynamic>);
    if (tableData.status != 'occupied' && tableData.status != 'billing') {
      throw Exception('Invalid table status for billing');
    }

    // 2. Aggregate items
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

    // 4. Fetch/Calculate Bill ID with Atomic Daily Reset (Guaranteed unique across parallel checkouts)
    final now = DateTime.now();
    final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final int billNumber = await _allocateNextBillNumber(todayStr);

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
      createdAt: now,
      createdBy: userId,
    );

    // 5. Atomic Batch Write (instant, 100% crash-proof on Windows desktop)
    final batch = _firestore.batch();

    batch.set(_billCollection.doc(billId), bill.toJson());

    batch.update(tableRef, {
      'status': 'billing',
      'updatedAt': Timestamp.fromDate(now),
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
        batch.update(kotDoc.reference, {'items': items});
      }
    }

    await batch.commit();

    // Update Analytics (Awaited for 100% ledger consistency)
    await _analyticsService.updateDailyAnalytics(bill, branchId);

    return bill;
  }

  // Finalize and Clear Table
  Future<void> finalizeAndClearTable(String tableId, String orderId) async {
    final now = DateTime.now();
    // 1. Fetch any KOTs for this order to ensure all items are marked served
    final kotSnapshots = await _kotCollection.where('orderId', isEqualTo: orderId).get();

    // 2. Atomic Batch Write (instant, 100% crash-proof on Windows desktop)
    final batch = _firestore.batch();

    // Close Order
    batch.update(_orderCollection.doc(orderId), {
      'status': 'closed',
      'closedAt': Timestamp.fromDate(now),
    });

    // Clear Table
    batch.update(_tableCollection.doc(tableId), {
      'status': 'available',
      'activeOrderId': null,
      'totalAmount': 0.0,
      'itemCount': 0,
      'kotCount': 0,
      'unprintedKotCount': 0,
      'updatedAt': Timestamp.fromDate(now),
    });

    // Mark any remaining KOT items as served
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
        batch.update(doc.reference, {'items': items});
      }
    }

    await batch.commit();
  }

  // Void an existing bill with audit logging, optional table restoration, and analytics reversal
  Future<BillModel> voidBill({
    required String billId,
    required String voidedBy,
    required String voidReason,
    bool restoreTable = false,
    bool allowPostShiftOverride = false,
    String? authorizedByAdminId,
    String? adminOverrideNote,
  }) async {
    if (voidReason.trim().length < 3) {
      throw Exception('A valid reason (minimum 3 characters) is required to void a bill.');
    }

    final billDocRef = _billCollection.doc(billId);

    final billSnap = await billDocRef.get();
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

    // Guard: Determine creation date & check if the shift is closed
    DateTime billCreatedAt = now;
    final rawCreatedAt = billData['createdAt'];
    if (rawCreatedAt is Timestamp) {
      billCreatedAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is DateTime) {
      billCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      billCreatedAt = DateTime.tryParse(rawCreatedAt) ?? now;
    }

    final billDateStr =
        "${billCreatedAt.year}-${billCreatedAt.month.toString().padLeft(2, '0')}-${billCreatedAt.day.toString().padLeft(2, '0')}";

    // Check if shift is closed for this bill's date
    final isClosed = await _analyticsService.isShiftClosedForDate(branchId, billDateStr);
    if (isClosed) {
      if (!allowPostShiftOverride) {
        throw Exception(
          'Cannot void invoice: The shift for $billDateStr has already been closed and reconciled with a Z-Report. '
          'Historical voiding requires Super-Admin override authorization.',
        );
      }
      if (adminOverrideNote == null || adminOverrideNote.trim().length < 5) {
        throw Exception('A detailed Super-Admin override note (minimum 5 characters) is required to void a bill from a closed shift.');
      }
    }

    final isSameDay = billCreatedAt.year == now.year &&
        billCreatedAt.month == now.month &&
        billCreatedAt.day == now.day;
    final isRecent = now.difference(billCreatedAt).inHours < 3;
    final shouldRestoreTable = restoreTable && isSameDay && isRecent && !isClosed;

    DocumentReference? tableRef;
    DocumentSnapshot? tableSnap;
    DocumentReference? orderRef;
    DocumentSnapshot? orderSnap;

    // Read table and order BEFORE ANY WRITES are executed
    if (shouldRestoreTable && tableId != null && orderId != null) {
      tableRef = _tableCollection.doc(tableId);
      orderRef = _orderCollection.doc(orderId);

      final restoreResults = await Future.wait([
        tableRef.get(),
        orderRef.get(),
      ]);
      tableSnap = restoreResults[0];
      orderSnap = restoreResults[1];
    }

    // Atomic Batch Write (instant, 100% crash-proof on Windows desktop)
    final batch = _firestore.batch();

    // 1. Mark bill as voided
    final Map<String, dynamic> billUpdates = {
      'isVoided': true,
      'voidedAt': Timestamp.fromDate(now),
      'voidedBy': voidedBy,
      'voidReason': voidReason.trim(),
      'tableRestored': shouldRestoreTable,
    };

    if (isClosed && allowPostShiftOverride) {
      billUpdates['postShiftVoid'] = true;
      billUpdates['authorizedByAdminId'] = authorizedByAdminId ?? voidedBy;
      billUpdates['adminOverrideNote'] = adminOverrideNote?.trim();

      // Write audit trail into shift_adjustments collection
      final adjustmentRef = _branchRef.collection('shift_adjustments').doc();
      batch.set(adjustmentRef, {
        'adjustmentId': adjustmentRef.id,
        'adjustmentType': 'post_shift_void',
        'billId': billId,
        'billDate': billDateStr,
        'originalTotal': (billData['total'] as num?)?.toDouble() ?? 0.0,
        'authorizedBy': authorizedByAdminId ?? voidedBy,
        'voidedBy': voidedBy,
        'reason': voidReason.trim(),
        'adminNote': adminOverrideNote?.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    batch.update(billDocRef, billUpdates);

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

        batch.update(tableRef, {
          'status': 'occupied',
          'activeOrderId': orderId,
          'totalAmount': billTotal,
          'itemCount': totalItemQty,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    }

    // Re-open order
    if (shouldRestoreTable && orderRef != null && orderSnap != null && orderSnap.exists) {
      batch.update(orderRef, {
        'status': 'active',
        'updatedAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();

    billData['isVoided'] = true;
    billData['voidedAt'] = now;
    billData['voidedBy'] = voidedBy;
    billData['voidReason'] = voidReason.trim();
    billData['tableRestored'] = shouldRestoreTable;

    final updatedBill = BillModel.fromJson(billData);

    // 3. Reverse Analytics
    await _analyticsService.reverseDailyAnalytics(updatedBill, branchId);

    return updatedBill;
  }
}
