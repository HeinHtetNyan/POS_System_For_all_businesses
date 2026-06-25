import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_repository.dart';
import '../../../models/analytics_model.dart';

class AnalyticsState {
  final DashboardKpiModel? kpi;
  final List<SalesSummaryPoint> salesPoints;
  final List<TopProductModel> topProducts;
  final bool isLoading;
  final String? error;
  final String period;
  /// Non-null when a custom date range is active.
  final DateTime? customStart;
  final DateTime? customEnd;

  const AnalyticsState({
    this.kpi,
    this.salesPoints = const [],
    this.topProducts = const [],
    this.isLoading = false,
    this.error,
    this.period = '7d',
    this.customStart,
    this.customEnd,
  });

  AnalyticsState copyWith({
    DashboardKpiModel? kpi,
    List<SalesSummaryPoint>? salesPoints,
    List<TopProductModel>? topProducts,
    bool? isLoading,
    String? error,
    String? period,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearError = false,
    bool clearCustom = false,
  }) {
    return AnalyticsState(
      kpi: kpi ?? this.kpi,
      salesPoints: salesPoints ?? this.salesPoints,
      topProducts: topProducts ?? this.topProducts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      period: period ?? this.period,
      customStart: clearCustom ? null : (customStart ?? this.customStart),
      customEnd: clearCustom ? null : (customEnd ?? this.customEnd),
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final AnalyticsRepository _repo;
  AnalyticsNotifier(this._repo) : super(const AnalyticsState());

  Future<void> load({String? period}) async {
    final selectedPeriod = period ?? state.period;
    state = AnalyticsState(isLoading: true, period: selectedPeriod);

    try {
      final results = await Future.wait([
        // FIX C-12: no period param sent to getDashboard
        _repo.getDashboard(),
        _repo.getSalesSummary(groupBy: selectedPeriod == '1d' ? 'hour' : 'day'),
        _repo.getTopProducts(limit: 10),
      ]);

      state = AnalyticsState(
        kpi: results[0] as DashboardKpiModel,
        salesPoints: results[1] as List<SalesSummaryPoint>,
        topProducts: results[2] as List<TopProductModel>,
        isLoading: false,
        period: selectedPeriod,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadCustomRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = AnalyticsState(
      isLoading: true,
      period: state.period,
      customStart: startDate,
      customEnd: endDate,
    );

    final fromStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final toStr =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

    try {
      final results = await Future.wait([
        // FIX C-12: no period param
        _repo.getDashboard(),
        // FIX C-09: renamed params
        _repo.getSalesSummary(startDate: fromStr, endDate: toStr),
        _repo.getTopProducts(startDate: fromStr, endDate: toStr, limit: 10),
      ]);

      state = AnalyticsState(
        kpi: results[0] as DashboardKpiModel,
        salesPoints: results[1] as List<SalesSummaryPoint>,
        topProducts: results[2] as List<TopProductModel>,
        isLoading: false,
        period: state.period,
        customStart: startDate,
        customEnd: endDate,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setPeriod(String period) {
    if (period == state.period && state.customStart == null) return;
    load(period: period);
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref.watch(analyticsRepositoryProvider));
});

// FIX H-10: FutureProvider.family keyed by (period, startDate?, endDate?)
// so Inventory, Customers, and Financial tabs can forward custom date ranges.

/// Key type for date-range-aware family providers.
/// Holds (period, startDate, endDate) — nullable dates mean "use period".
typedef _DateRangeKey = ({String period, String? startDate, String? endDate});

final inventorySummaryProvider =
    FutureProvider.family<Map<String, dynamic>, _DateRangeKey>((ref, key) async {
  return ref.watch(analyticsRepositoryProvider).getInventorySummary(
        startDate: key.startDate,
        endDate: key.endDate,
      );
});

final customersSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, _DateRangeKey>((ref, key) async {
  return ref.watch(analyticsRepositoryProvider).getCustomersSummary(
        startDate: key.startDate,
        endDate: key.endDate,
      );
});

final financialSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, _DateRangeKey>((ref, key) async {
  return ref.watch(analyticsRepositoryProvider).getFinancialSummary(
        startDate: key.startDate,
        endDate: key.endDate,
      );
});

final deadStockProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, days) async {
  return ref.watch(analyticsRepositoryProvider).getDeadStock(days: days);
});
