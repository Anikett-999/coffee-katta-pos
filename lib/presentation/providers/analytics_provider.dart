import '../../services/analytics_service.dart';
import '../../domain/models/daily_analytics.dart';
import '../../domain/models/bill_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analytics_provider.g.dart';

@riverpod
class AnalyticsDateSelection extends _$AnalyticsDateSelection {
  @override
  Map<String, dynamic> build() {
    return {
      'start': DateTime.now(),
      'end': null,
      'isRange': false,
    };
  }

  void setSingleDate(DateTime date) {
    state = {
      'start': date,
      'end': null,
      'isRange': false,
    };
  }

  void setRange(DateTime start, DateTime end) {
    state = {
      'start': start,
      'end': end,
      'isRange': true,
    };
  }

  void toggleRange(bool isRange) {
    state = {
      ...state,
      'isRange': isRange,
      'end': isRange ? (state['end'] ?? DateTime.now()) : null,
    };
  }
}

@riverpod
Stream<DailyAnalytics> dailyAnalytics(DailyAnalyticsRef ref, {required String branchId}) {
  final selection = ref.watch(analyticsDateSelectionProvider);
  final service = AnalyticsService();
  
  final start = selection['start'] as DateTime;
  final end = selection['end'] as DateTime?;
  final isRange = selection['isRange'] as bool;

  if (!isRange) {
    // Return a stream that updates whenever the daily document changes in Firestore
    return service.watchDailyAnalytics(branchId, start);
  } else {
    // For ranges, we fetch the merged report as a stream that emits once.
    // If we wanted true real-time range merges, we'd need a more complex CombineLatest scenario,
    // but for the reports dashboard, a refresh-on-entry/sync is standard.
    return Stream.fromFuture(service.getAnalyticsReport(branchId, start, end));
  }
}

/// Fetches individual bills for the active date selection (used by Invoice Register & CSV export)
final billsForPeriodProvider = FutureProvider.family<List<BillModel>, String>((ref, branchId) async {
  final selection = ref.watch(analyticsDateSelectionProvider);
  final start = selection['start'] as DateTime;
  final end = selection['end'] as DateTime?;
  final service = AnalyticsService();
  return service.getBillsForRange(branchId, start, end);
});

