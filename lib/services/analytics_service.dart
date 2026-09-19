import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

import '../domain/models/bill_model.dart';
import '../domain/models/kot_model.dart';
import '../domain/models/table_model.dart';
import '../domain/models/dashboard_stats.dart';
import '../domain/models/product_insights.dart';
import '../domain/models/daily_analytics.dart';
import 'package:intl/intl.dart';


class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _businessId = 'coffee_katta';

  DocumentReference _getBranchRef(String branchId) {
    return _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('branches')
        .doc(branchId);
  }

  // --- Safe Parsing Helpers ---

  static BillModel? safeParseBillData(Map<dynamic, dynamic> rawData, [String? docId]) {
    try {
      final data = Map<String, dynamic>.from(rawData);

      final billId = data['billId'] ?? docId;
      if (billId == null) return null;
      // FILTER: Only process new format bills (starting with INV-)
      if (!billId.toString().startsWith('INV-')) {
        return null; 
      }

      // Inject IDs and provide structural fallbacks
      data['billId'] = billId.toString();
      data['orderId'] = data['orderId']?.toString() ?? 'N/A';
      data['tableId'] = data['tableId']?.toString() ?? 'N/A';
      data['tableName'] = data['tableName']?.toString() ?? 'N/A';
      data['userName'] = data['userName']?.toString() ?? 'N/A';
      data['createdBy'] = data['createdBy']?.toString() ?? 'N/A';

      // Ensure nested maps are safely converted to Map<String, dynamic>
      if (data['items'] is List) {
        data['items'] = (data['items'] as List).map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return item;
        }).toList();
      } else {
        data['items'] = [];
      }

      if (data['payments'] is List) {
        data['payments'] = (data['payments'] as List).map((pay) {
          if (pay is Map) {
            return Map<String, dynamic>.from(pay);
          }
          return pay;
        }).toList();
      } else {
        data['payments'] = [];
      }
      
      // Ensure numeric fields are non-null and doubles
      data['subtotal'] = (data['subtotal'] ?? 0.0).toDouble();
      data['total'] = (data['total'] ?? 0.0).toDouble();
      data['discountPercent'] = (data['discountPercent'] ?? 0.0).toDouble();
      data['discountAmount'] = (data['discountAmount'] ?? 0.0).toDouble();
      data['extraCharges'] = (data['extraCharges'] ?? 0.0).toDouble();
      data['isVoided'] = data['isVoided'] ?? false;
      data['tableRestored'] = data['tableRestored'] ?? false;

      // Ensure createdAt exists
      if (data['createdAt'] == null) return null;

      return BillModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  BillModel? _safeParseBill(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    return safeParseBillData(data, doc.id);
  }

  TableModel? _safeParseTable(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      data['tableId'] = data['tableId'] ?? doc.id;
      
      // Handle timestamp to string conversion for UI stability
      if (data['updatedAt'] is Timestamp) {
        data['updatedAt'] = (data['updatedAt'] as Timestamp).toDate().toIso8601String();
      }
      
      return TableModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  KOTModel? _safeParseKOT(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      data['kotId'] = data['kotId'] ?? doc.id;
      data['orderId'] = data['orderId'] ?? 'N/A';
      
      return KOTModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  // --- Analytics Streams ---

  Stream<DashboardStats> watchDashboardStats(String branchId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final branchRef = _getBranchRef(branchId);

    // Fetch snapshots without strict timestamp filter to allow for the legacy String format transition.
    return branchRef.collection('bills').snapshots().map((billsSnap) {
      final bills = billsSnap.docs
          .map((doc) => _safeParseBill(doc))
          .whereType<BillModel>()
          .where((b) => !b.isVoided && b.createdAt.isAfter(startOfDay.subtract(const Duration(seconds: 1))))
          .toList();
      // For simplicity in this stream-based architecture, we'll keep the combine3 approach 
      // but the key fix is the bill filtering above.
      // Re-implementing correctly with combine for the dashboard
      return bills;
    }).switchMap((bills) {
      // Re-using the logic from the previous turn but correctly integrated
      return CombineLatestStream.combine2(
        branchRef.collection('tables').snapshots(),
        branchRef.collection('kots').snapshots(),
        (tablesSnap, kotsSnap) {
          final tables = tablesSnap.docs.map((doc) => _safeParseTable(doc)).whereType<TableModel>().toList();
          final kots = kotsSnap.docs
              .map((doc) => _safeParseKOT(doc))
              .whereType<KOTModel>()
              .where((k) => k.createdAt.isAfter(startOfDay))
              .toList();

          double totalRevenue = 0;
          double grossSales = 0;
          double totalDiscounts = 0;
          Map<String, double> payments = {'cash': 0.0, 'upi': 0.0, 'card': 0.0};
          Map<int, double> hourlyRevenue = {};
          Map<String, TopProduct> productMap = {};

          for (final bill in bills) {
            totalRevenue += bill.total;
            grossSales += bill.subtotal + bill.extraCharges;
            totalDiscounts += bill.discountAmount;
            
            for (final p in bill.payments) {
              final mode = p.mode.toLowerCase();
              payments[mode] = (payments[mode] ?? 0.0) + p.amount;
            }

            final hour = bill.createdAt.hour;
            hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0.0) + bill.total;

            for (final item in bill.items) {
              final existing = productMap[item.name];
              if (existing != null) {
                productMap[item.name] = existing.copyWith(
                  quantity: existing.quantity + item.qty,
                  revenue: existing.revenue + (item.qty * item.price),
                );
              } else {
                productMap[item.name] = TopProduct(
                  name: item.name,
                  quantity: item.qty,
                  revenue: item.qty * item.price,
                );
              }
            }
          }

          final activeTables = tables.where((t) => t.status != 'available').length;
          final pendingKots = kots.where((k) => !k.isPrinted).length;

          final suspicious = bills
              .where((b) => b.isSuspicious || b.printCount > 1)
              .map((b) => SuspiciousBill(
                    billId: b.billId,
                    printCount: b.printCount,
                    tableId: b.tableName,
                    total: b.total,
                    createdAt: b.createdAt,
                  ))
              .toList();

          final List<HourlySales> salesTrend = List.generate(24, (dayHour) {
            return HourlySales(hour: dayHour, revenue: hourlyRevenue[dayHour] ?? 0.0);
          });

          final topProducts = productMap.values.toList()
            ..sort((a, b) => b.revenue.compareTo(a.revenue));

          return DashboardStats(
            totalRevenue: totalRevenue,
            grossSales: grossSales,
            totalDiscounts: totalDiscounts,
            totalOrders: bills.length,
            avgOrderValue: bills.isEmpty ? 0 : totalRevenue / bills.length,
            revenueTrend: 0.0,
            ordersTrend: 0.0,
            hourlySales: salesTrend,
            paymentSplit: payments,
            activeTables: activeTables,
            pendingKots: pendingKots,
            topProducts: topProducts.take(10).toList(),
            suspiciousBills: suspicious,
          );
        },
      );
    });
  }

  Stream<ProductInsights> watchProductInsights(String branchId) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final branchRef = _getBranchRef(branchId);

    return branchRef.collection('bills').snapshots().map((billsSnap) {
      final bills = billsSnap.docs
          .map((doc) => _safeParseBill(doc))
          .whereType<BillModel>()
          .where((b) => !b.isVoided && b.createdAt.isAfter(thirtyDaysAgo.subtract(const Duration(seconds: 1))))
          .toList();

      Map<String, TopProduct> itemMap = {};
      Map<String, TopCategory> categoryMap = {};
      int totalQty = 0;
      double totalRev = 0;

      for (final bill in bills) {
        for (final item in bill.items) {
          totalQty += item.qty;
          totalRev += (item.qty * item.price);

          final existingItem = itemMap[item.name];
          if (existingItem != null) {
            itemMap[item.name] = existingItem.copyWith(
              quantity: existingItem.quantity + item.qty,
              revenue: existingItem.revenue + (item.qty * item.price),
            );
          } else {
            itemMap[item.name] = TopProduct(
              name: item.name,
              quantity: item.qty,
              revenue: item.qty * item.price,
            );
          }

          final catName = item.category.isEmpty ? 'Uncategorized' : item.category;
          final existingCat = categoryMap[catName];
          if (existingCat != null) {
            categoryMap[catName] = existingCat.copyWith(
              quantity: existingCat.quantity + item.qty,
              revenue: existingCat.revenue + (item.qty * item.price),
            );
          } else {
            categoryMap[catName] = TopCategory(
              name: catName,
              quantity: item.qty,
              revenue: item.qty * item.price,
            );
          }
        }
      }

      final sortedItems = itemMap.values.toList()..sort((a, b) => b.quantity.compareTo(a.quantity));
      final sortedCats = categoryMap.values.toList()..sort((a, b) => b.quantity.compareTo(a.quantity));

      return ProductInsights(
        topItems: sortedItems,
        topCategories: sortedCats,
        totalQuantity: totalQty,
        totalRevenue: totalRev,
      );
    });
  }

  Stream<DashboardStats> watchReportForRange(String branchId, DateTime start, DateTime end) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final branchRef = _getBranchRef(branchId);

    return branchRef.collection('bills').snapshots().map((billsSnap) {
      final bills = billsSnap.docs
          .map((doc) => _safeParseBill(doc))
          .whereType<BillModel>()
          .where((b) {
            return !b.isVoided &&
                   b.createdAt.isAfter(rangeStart.subtract(const Duration(seconds: 1))) && 
                   b.createdAt.isBefore(rangeEnd.add(const Duration(seconds: 1)));
          })
          .toList();

      double totalRevenue = 0;
      double grossSales = 0;
      double totalDiscounts = 0;
      Map<String, double> payments = {'cash': 0.0, 'upi': 0.0, 'card': 0.0};
      Map<int, double> hourlyRevenue = {};
      Map<String, TopProduct> productMap = {};

      for (final bill in bills) {
        totalRevenue += bill.total;
        grossSales += bill.subtotal + bill.extraCharges;
        totalDiscounts += bill.discountAmount;
        
        for (final p in bill.payments) {
          final mode = p.mode.toLowerCase();
          payments[mode] = (payments[mode] ?? 0.0) + p.amount;
        }

        final hour = bill.createdAt.hour;
        hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0.0) + bill.total;

        for (final item in bill.items) {
          final existing = productMap[item.name];
          if (existing != null) {
            productMap[item.name] = existing.copyWith(
              quantity: existing.quantity + item.qty,
              revenue: existing.revenue + (item.qty * item.price),
            );
          } else {
            productMap[item.name] = TopProduct(
              name: item.name,
              quantity: item.qty,
              revenue: item.qty * item.price,
            );
          }
        }
      }

      final List<HourlySales> salesTrend = List.generate(24, (dayHour) {
        return HourlySales(hour: dayHour, revenue: hourlyRevenue[dayHour] ?? 0.0);
      });

      final topProducts = productMap.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      return DashboardStats(
        totalRevenue: totalRevenue,
        grossSales: grossSales,
        totalDiscounts: totalDiscounts,
        totalOrders: bills.length,
        avgOrderValue: bills.isEmpty ? 0 : totalRevenue / bills.length,
        revenueTrend: 0.0,
        ordersTrend: 0.0,
        hourlySales: salesTrend,
        paymentSplit: payments,
        activeTables: 0,
        pendingKots: 0,
        topProducts: topProducts.take(15).toList(),
        suspiciousBills: [],
      );
    });
  }

  // --- Pre-Aggregation Analytics (The New Performance Strategy) ---

  String _sanitizeKey(String key) {
    return key.replaceAll('.', '_').replaceAll('/', '_').replaceAll('[', '_').replaceAll(']', '_').replaceAll('#', '_').replaceAll(r'$', '_');
  }

  Future<void> updateDailyAnalytics(BillModel bill, String branchId) async {
    // FILTER: Only update analytics for new format bills
    if (!bill.billId.startsWith('INV-')) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(bill.createdAt);
    final hourKey = bill.createdAt.hour.toString();
    final branchRef = _getBranchRef(branchId);
    final dailyDoc = branchRef.collection('analytics_daily').doc(dateKey);

    // Build the dot-notation map for update()
    final Map<String, dynamic> updateData = {
      'totalSales': FieldValue.increment(bill.total),
      'totalBills': FieldValue.increment(1),
      'totalDiscount': FieldValue.increment(bill.discountAmount),
      'extraCharges': FieldValue.increment(bill.extraCharges),
    };

    // Add Payment Stats
    for (final p in bill.payments) {
      final mode = p.mode.toLowerCase();
      updateData['paymentStats.$mode'] = FieldValue.increment(p.amount);
    }

    // Add Hourly Stats
    updateData['hourlyStats.$hourKey.sales'] = FieldValue.increment(bill.total);
    updateData['hourlyStats.$hourKey.orders'] = FieldValue.increment(1);

    // Add Item & Category Stats
    for (final item in bill.items) {
      final safeName = _sanitizeKey(item.name);
      updateData['itemStats.$safeName.name'] = item.name;
      updateData['itemStats.$safeName.qty'] = FieldValue.increment(item.qty);
      updateData['itemStats.$safeName.revenue'] = FieldValue.increment(item.qty * item.price);

      final safeCategory = _sanitizeKey(item.category.isEmpty ? 'Uncategorized' : item.category);
      updateData['categoryStats.$safeCategory'] = FieldValue.increment(item.qty * item.price);
    }

    // Add User Stats
    final safeUser = _sanitizeKey(bill.userName.isEmpty ? 'System' : bill.userName);
    updateData['userStats.$safeUser'] = FieldValue.increment(bill.total);

    // Add Delivery/Table Stats
    final safeTable = _sanitizeKey(bill.tableName.isEmpty ? 'Unknown' : bill.tableName);
    updateData['deliveryMethodsStats.$safeTable'] = FieldValue.increment(1);

    try {
      // Use update() because it correctly interprets dot-notation keys for deep nesting
      await dailyDoc.update(updateData);
    } catch (e) {
      // If document doesn't exist, we must use set() but with a NESTED structure
      // set() does NOT interpret dot-notation keys as deep paths.
      final Map<String, dynamic> nestedData = {
        'totalSales': bill.total,
        'totalBills': 1,
        'totalDiscount': bill.discountAmount,
        'extraCharges': bill.extraCharges,
        'paymentStats': {},
        'hourlyStats': {},
        'itemStats': {},
      };

      for (final p in bill.payments) {
        nestedData['paymentStats'][p.mode.toLowerCase()] = p.amount;
      }

      nestedData['hourlyStats'][hourKey] = {
        'sales': bill.total,
        'orders': 1,
      };

      for (final item in bill.items) {
        final safeName = _sanitizeKey(item.name);
        nestedData['itemStats'][safeName] = {
          'name': item.name,
          'qty': item.qty,
          'revenue': item.qty * item.price,
        };
        final safeCategory = _sanitizeKey(item.category.isEmpty ? 'Uncategorized' : item.category);
        nestedData['categoryStats'] ??= {};
        nestedData['categoryStats'][safeCategory] = (nestedData['categoryStats'][safeCategory] ?? 0.0) + (item.qty * item.price);
      }

      final safeUser = _sanitizeKey(bill.userName.isEmpty ? 'System' : bill.userName);
      nestedData['userStats'] = {safeUser: bill.total};

      final safeTable = _sanitizeKey(bill.tableName.isEmpty ? 'Unknown' : bill.tableName);
      nestedData['deliveryMethodsStats'] = {safeTable: 1.0};

      await dailyDoc.set(nestedData, SetOptions(merge: true));
    }
  }

  /// Reverses daily analytics for a voided bill by decrementing counters and totals
  Future<void> reverseDailyAnalytics(BillModel bill, String branchId) async {
    if (!bill.billId.startsWith('INV-')) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(bill.createdAt);
    final hourKey = bill.createdAt.hour.toString();
    final branchRef = _getBranchRef(branchId);
    final dailyDoc = branchRef.collection('analytics_daily').doc(dateKey);

    // Build the dot-notation map with negative increments
    final Map<String, dynamic> updateData = {
      'totalSales': FieldValue.increment(-bill.total),
      'totalBills': FieldValue.increment(-1),
      'totalDiscount': FieldValue.increment(-bill.discountAmount),
      'extraCharges': FieldValue.increment(-bill.extraCharges),
    };

    // Decrement Payment Stats
    for (final p in bill.payments) {
      final mode = p.mode.toLowerCase();
      updateData['paymentStats.$mode'] = FieldValue.increment(-p.amount);
    }

    // Decrement Hourly Stats
    updateData['hourlyStats.$hourKey.sales'] = FieldValue.increment(-bill.total);
    updateData['hourlyStats.$hourKey.orders'] = FieldValue.increment(-1);

    // Decrement Item & Category Stats
    for (final item in bill.items) {
      final safeName = _sanitizeKey(item.name);
      updateData['itemStats.$safeName.qty'] = FieldValue.increment(-item.qty);
      updateData['itemStats.$safeName.revenue'] = FieldValue.increment(-(item.qty * item.price));

      final safeCategory = _sanitizeKey(item.category.isEmpty ? 'Uncategorized' : item.category);
      updateData['categoryStats.$safeCategory'] = FieldValue.increment(-(item.qty * item.price));
    }

    // Decrement User Stats
    final safeUser = _sanitizeKey(bill.userName.isEmpty ? 'System' : bill.userName);
    updateData['userStats.$safeUser'] = FieldValue.increment(-bill.total);

    // Decrement Delivery/Table Stats
    final safeTable = _sanitizeKey(bill.tableName.isEmpty ? 'Unknown' : bill.tableName);
    updateData['deliveryMethodsStats.$safeTable'] = FieldValue.increment(-1);

    try {
      await dailyDoc.update(updateData);
    } catch (e) {
      debugPrint('Error reversing daily analytics for voided bill ${bill.billId}: $e');
    }
  }

  Stream<DailyAnalytics> watchDailyAnalytics(String branchId, DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _getBranchRef(branchId)
        .collection('analytics_daily')
        .doc(dateKey)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return const DailyAnalytics();
          return DailyAnalytics.fromJson(doc.data() as Map<String, dynamic>);
        });
  }

  Future<DailyAnalytics> getAnalyticsReport(String branchId, DateTime start, [DateTime? end]) async {
    final branchRef = _getBranchRef(branchId);
    
    if (end == null || DateFormat('yyyy-MM-dd').format(start) == DateFormat('yyyy-MM-dd').format(end)) {
      // Single day
      final dateKey = DateFormat('yyyy-MM-dd').format(start);
      final doc = await branchRef.collection('analytics_daily').doc(dateKey).get();
      if (!doc.exists) return const DailyAnalytics();
      return DailyAnalytics.fromJson(doc.data() as Map<String, dynamic>);
    }

    // Date range
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    
    final startKey = DateFormat('yyyy-MM-dd').format(startDate);
    final endKey = DateFormat('yyyy-MM-dd').format(endDate);

    final query = await branchRef.collection('analytics_daily')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .get();

    DailyAnalytics merged = const DailyAnalytics();
    for (var doc in query.docs) {
      final data = DailyAnalytics.fromJson(doc.data());
      merged = DailyAnalytics.merge(merged, data);
    }

    return merged;
  }

  /// One-time utility to sync historical bills into pre-aggregated analytics
  Future<void> syncHistoricalData(String branchId) async {
    final branchRef = _getBranchRef(branchId);
    final billsSnap = await branchRef.collection('bills').get();

    // Group bills by date to minimize Firestore writes
    final Map<String, List<BillModel>> groupedBills = {};
    for (var doc in billsSnap.docs) {
      final bill = _safeParseBill(doc);
      if (bill != null && !bill.isVoided) {
        final dateKey = DateFormat('yyyy-MM-dd').format(bill.createdAt);
        groupedBills.putIfAbsent(dateKey, () => []).add(bill);
      }
    }

    // For each date, rebuild the document locally then save
    for (var entry in groupedBills.entries) {
      final dateKey = entry.key;
      final bills = entry.value;
      
      double totalSales = 0;
      double totalDiscount = 0;
      double extraCharges = 0;
      Map<String, double> paymentStats = {};
      Map<String, HourStat> hourlyStats = {};
      Map<String, ItemStat> itemStats = {};

      Map<String, double> categoryStats = {};
      Map<String, double> userStats = {};
      Map<String, double> deliveryMethodsStats = {};

      for (var bill in bills) {
        totalSales += bill.total;
        totalDiscount += bill.discountAmount;
        extraCharges += bill.extraCharges;

        for (var p in bill.payments) {
          final mode = p.mode.toLowerCase();
          paymentStats[mode] = (paymentStats[mode] ?? 0.0) + p.amount;
        }

        final hourKey = bill.createdAt.hour.toString();
        final hStat = hourlyStats[hourKey] ?? const HourStat();
        hourlyStats[hourKey] = hStat.copyWith(
          sales: hStat.sales + bill.total,
          orders: hStat.orders + 1,
        );

        final safeUser = _sanitizeKey(bill.userName.isEmpty ? 'System' : bill.userName);
        userStats[safeUser] = (userStats[safeUser] ?? 0.0) + bill.total;

        final safeTable = _sanitizeKey(bill.tableName.isEmpty ? 'Unknown' : bill.tableName);
        deliveryMethodsStats[safeTable] = (deliveryMethodsStats[safeTable] ?? 0.0) + 1;

        for (var item in bill.items) {
          final safeName = _sanitizeKey(item.name);
          final iStat = itemStats[safeName] ?? ItemStat(name: item.name);
          itemStats[safeName] = iStat.copyWith(
            qty: iStat.qty + item.qty,
            revenue: iStat.revenue + (item.qty * item.price),
          );

          final safeCategory = _sanitizeKey(item.category.isEmpty ? 'Uncategorized' : item.category);
          categoryStats[safeCategory] = (categoryStats[safeCategory] ?? 0.0) + (item.qty * item.price);
        }
      }

      final analytics = DailyAnalytics(
        totalSales: totalSales,
        totalBills: bills.length,
        totalDiscount: totalDiscount,
        extraCharges: extraCharges,
        paymentStats: paymentStats,
        hourlyStats: hourlyStats,
        itemStats: itemStats,
        categoryStats: categoryStats,
        userStats: userStats,
        deliveryMethodsStats: deliveryMethodsStats,
      );

      await branchRef.collection('analytics_daily').doc(dateKey).set(analytics.toJson());
    }
  }

  /// Query bills bounded by date range with safe parsing for invoice register
  Future<List<BillModel>> getBillsForRange(String branchId, DateTime start, [DateTime? end, int limit = 150]) async {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = end != null 
        ? DateTime(end.year, end.month, end.day, 23, 59, 59)
        : DateTime(start.year, start.month, start.day, 23, 59, 59);

    final branchRef = _getBranchRef(branchId);
    try {
      final snap = await branchRef
          .collection('bills')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final bills = snap.docs
          .map((doc) => _safeParseBill(doc))
          .whereType<BillModel>()
          .toList();
      return bills;
    } catch (e) {
      // Fallback in case composite index is building or for legacy string dates
      final snap = await branchRef.collection('bills').limit(limit).get();
      final bills = snap.docs
          .map((doc) => _safeParseBill(doc))
          .whereType<BillModel>()
          .where((b) => b.createdAt.isAfter(rangeStart.subtract(const Duration(seconds: 1))) &&
                        b.createdAt.isBefore(rangeEnd.add(const Duration(seconds: 1))))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bills;
    }
  }

  /// Real-time stream of bills bounded by date range with safe parsing for invoice register
  Stream<List<BillModel>> watchBillsForRange(String branchId, DateTime start, [DateTime? end, int limit = 150]) async* {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = end != null 
        ? DateTime(end.year, end.month, end.day, 23, 59, 59)
        : DateTime(start.year, start.month, start.day, 23, 59, 59);

    final branchRef = _getBranchRef(branchId);
    
    try {
      final stream = branchRef
          .collection('bills')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd))
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots();

      await for (final snap in stream) {
        final bills = snap.docs
            .map((doc) => _safeParseBill(doc))
            .whereType<BillModel>()
            .toList();
        yield bills;
      }
    } catch (_) {
      // Fallback in case of index issues or legacy formats
      final fallbackStream = branchRef.collection('bills').limit(limit).snapshots();
      await for (final snap in fallbackStream) {
        final bills = snap.docs
            .map((doc) => _safeParseBill(doc))
            .whereType<BillModel>()
            .where((b) => b.createdAt.isAfter(rangeStart.subtract(const Duration(seconds: 1))) &&
                          b.createdAt.isBefore(rangeEnd.add(const Duration(seconds: 1))))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield bills;
      }
    }
  }

  /// Save shift cash drawer reconciliation & audit record to Firestore
  Future<void> saveShiftClosing({
    required String branchId,
    required String dateStr,
    required double openingFloat,
    required double expectedCashSales,
    required double totalExpectedDrawerCash,
    required double physicalCashCounted,
    required double cashVariance,
    required String varianceStatus,
    required String closedByUserId,
    required String closedByUserName,
    required double grossSales,
    required double netRevenue,
    required int totalBills,
    required Map<String, double> paymentStats,
  }) async {
    final branchRef = _getBranchRef(branchId);
    final now = DateTime.now();
    final docId = 'shift_${dateStr.replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}';

    final data = {
      'closingId': docId,
      'branchId': branchId,
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
      'openingFloat': openingFloat,
      'expectedCashSales': expectedCashSales,
      'totalExpectedDrawerCash': totalExpectedDrawerCash,
      'physicalCashCounted': physicalCashCounted,
      'cashVariance': cashVariance,
      'varianceStatus': varianceStatus,
      'closedByUserId': closedByUserId,
      'closedByUserName': closedByUserName,
      'grossSales': grossSales,
      'netRevenue': netRevenue,
      'totalBills': totalBills,
      'paymentStats': paymentStats,
    };

    // 1. Audit log in shift_closings collection
    await branchRef.collection('shift_closings').doc(docId).set(data);

    // 2. Also record latest reconciliation in daily_stats
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    await branchRef.collection('daily_stats').doc(todayStr).set({
      'lastShiftClosing': data,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get latest saved shift closing for a branch and date
  Future<Map<String, dynamic>?> getLatestShiftClosing(String branchId, String dateStr) async {
    try {
      final branchRef = _getBranchRef(branchId);
      final snap = await branchRef
          .collection('shift_closings')
          .where('date', isEqualTo: dateStr)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting latest shift closing: $e');
      return null;
    }
  }
}
