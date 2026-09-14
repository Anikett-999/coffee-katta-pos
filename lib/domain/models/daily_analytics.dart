import 'package:freezed_annotation/freezed_annotation.dart';

part 'daily_analytics.freezed.dart';
part 'daily_analytics.g.dart';

@freezed
class DailyAnalytics with _$DailyAnalytics {
  const DailyAnalytics._();

  const factory DailyAnalytics({
    @Default(0.0) double totalSales,
    @Default(0) int totalBills,
    @Default(0.0) double totalDiscount,
    @Default(0.0) double extraCharges,
    @Default({}) Map<String, ItemStat> itemStats,
    @Default({}) Map<String, HourStat> hourlyStats,
    @Default({'cash': 0.0, 'upi': 0.0, 'card': 0.0}) Map<String, double> paymentStats,
    @Default({}) Map<String, double> categoryStats,
    @Default({}) Map<String, double> deliveryMethodsStats,
    @Default({}) Map<String, double> userStats,
  }) = _DailyAnalytics;

  // Financial accounting properties:
  // totalSales represents the total net payable collected from customers (subtotal - discount + extraCharges)
  double get grossSales => totalSales + totalDiscount - extraCharges;
  double get netSales => grossSales - totalDiscount;
  double get netRevenue => totalSales;
  double get aov => totalBills > 0 ? totalSales / totalBills : 0.0;

  factory DailyAnalytics.fromJson(Map<String, dynamic> json) => _$DailyAnalyticsFromJson(json);

  // Helper to merge two analytics objects (used for range reports)
  factory DailyAnalytics.merge(DailyAnalytics a, DailyAnalytics b) {
    // Merge Item Stats
    final mergedItemStats = Map<String, ItemStat>.from(a.itemStats);
    b.itemStats.forEach((name, stat) {
      final existing = mergedItemStats[name];
      if (existing != null) {
        mergedItemStats[name] = ItemStat(
          name: existing.name,
          qty: existing.qty + stat.qty,
          revenue: existing.revenue + stat.revenue,
        );
      } else {
        mergedItemStats[name] = stat;
      }
    });

    // Merge Hourly Stats
    final mergedHourlyStats = Map<String, HourStat>.from(a.hourlyStats);
    b.hourlyStats.forEach((hour, stat) {
      final existing = mergedHourlyStats[hour];
      if (existing != null) {
        mergedHourlyStats[hour] = HourStat(
          sales: existing.sales + stat.sales,
          orders: existing.orders + stat.orders,
        );
      } else {
        mergedHourlyStats[hour] = stat;
      }
    });

    // Merge Map<String, double> stats helper
    Map<String, double> mergeDoubleMaps(Map<String, double> mapA, Map<String, double> mapB) {
      final merged = Map<String, double>.from(mapA);
      mapB.forEach((key, val) {
        merged[key] = (merged[key] ?? 0.0) + val;
      });
      return merged;
    }

    return DailyAnalytics(
      totalSales: a.totalSales + b.totalSales,
      totalBills: a.totalBills + b.totalBills,
      totalDiscount: a.totalDiscount + b.totalDiscount,
      extraCharges: a.extraCharges + b.extraCharges,
      itemStats: mergedItemStats,
      hourlyStats: mergedHourlyStats,
      paymentStats: mergeDoubleMaps(a.paymentStats, b.paymentStats),
      categoryStats: mergeDoubleMaps(a.categoryStats, b.categoryStats),
      deliveryMethodsStats: mergeDoubleMaps(a.deliveryMethodsStats, b.deliveryMethodsStats),
      userStats: mergeDoubleMaps(a.userStats, b.userStats),
    );
  }
}

@freezed
class ItemStat with _$ItemStat {
  const factory ItemStat({
    @Default('') String name,
    @Default(0) int qty,
    @Default(0.0) double revenue,
  }) = _ItemStat;

  factory ItemStat.fromJson(Map<String, dynamic> json) => _$ItemStatFromJson(json);
}

@freezed
class HourStat with _$HourStat {
  const factory HourStat({
    @Default(0.0) double sales,
    @Default(0) int orders,
  }) = _HourStat;

  factory HourStat.fromJson(Map<String, dynamic> json) => _$HourStatFromJson(json);
}
