import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../providers/analytics_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../models/analytics_model.dart';

// FIX H-12: staff analytics accepts start_date/end_date instead of 'period' string.
// The family key is the period string; we compute dates inside the provider.
final _staffAnalyticsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, period) async {
  final dio = apiClient.dio;

  // Compute start_date from period
  final now = DateTime.now();
  final DateTime start;
  switch (period) {
    case '1d':
      start = DateTime(now.year, now.month, now.day);
      break;
    case '30d':
      start = now.subtract(const Duration(days: 30));
      break;
    case '90d':
      start = now.subtract(const Duration(days: 90));
      break;
    case '7d':
    default:
      start = now.subtract(const Duration(days: 7));
  }

  String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final params = <String, dynamic>{
    'start_date': fmt(start),
    'end_date': fmt(now),
  };
  final r = await dio.get('/analytics/sales/by-cashier', queryParameters: params);
  final raw = r.data as List<dynamic>? ?? [];
  return raw.cast<Map<String, dynamic>>();
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  DateTime? _customStart;
  DateTime? _customEnd;

  bool get _isCustomActive => _customStart != null && _customEnd != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    Future.microtask(() => ref.read(analyticsProvider.notifier).load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _isCustomActive
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryFg,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
      ref.read(analyticsProvider.notifier).loadCustomRange(
            startDate: picked.start,
            endDate: picked.end,
          );
    }
  }

  void _clearCustomRange() {
    setState(() {
      _customStart = null;
      _customEnd = null;
    });
    ref.read(analyticsProvider.notifier).setPeriod('7d');
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);
    final periods = ['1d', '7d', '30d', '90d'];
    final periodLabels = ['Today', '7 Days', '30 Days', '90 Days'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Analytics',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Period filter chips
              Container(
                color: AppColors.surface,
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    // Preset period chips
                    ...List.generate(periods.length, (i) {
                      final isSelected =
                          !_isCustomActive && state.period == periods[i];
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                        child: FilterChip(
                          label: Text(
                            periodLabels[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primaryFg
                                  : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            if (_isCustomActive) _clearCustomRange();
                            ref
                                .read(analyticsProvider.notifier)
                                .setPeriod(periods[i]);
                          },
                          backgroundColor: AppColors.surfaceVariant,
                          selectedColor: AppColors.primary,
                          checkmarkColor: AppColors.primaryFg,
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                          ),
                          showCheckmark: false,
                        ),
                      );
                    }),
                    // Custom range chip
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                      child: _isCustomActive
                          ? InputChip(
                              avatar: const Icon(Icons.date_range,
                                  size: 14, color: AppColors.primaryFg),
                              label: Text(
                                '${_fmtDate(_customStart!)} - ${_fmtDate(_customEnd!)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryFg),
                              ),
                              selected: true,
                              onSelected: (_) => _pickDateRange(),
                              onDeleted: _clearCustomRange,
                              deleteIconColor: AppColors.primaryFg,
                              backgroundColor: AppColors.primary,
                              selectedColor: AppColors.primary,
                              checkmarkColor: AppColors.primaryFg,
                              side: const BorderSide(color: AppColors.primary),
                              showCheckmark: false,
                            )
                          : FilterChip(
                              avatar: const Icon(Icons.date_range,
                                  size: 14, color: AppColors.textSecondary),
                              label: const Text(
                                'Custom',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary),
                              ),
                              selected: false,
                              onSelected: (_) => _pickDateRange(),
                              backgroundColor: AppColors.surfaceVariant,
                              selectedColor: AppColors.primary,
                              side:
                                  const BorderSide(color: AppColors.divider),
                              showCheckmark: false,
                            ),
                    ),
                  ],
                ),
              ),
              // Tab bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w400),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Sales'),
                  Tab(text: 'Inventory'),
                  Tab(text: 'Customers'),
                  Tab(text: 'Financial'),
                  Tab(text: 'Staff'),
                  Tab(icon: Icon(Icons.download_outlined), text: 'Export'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0 — Overview
          _OverviewTab(state: state),
          // Tab 1 — Sales
          _SalesTab(state: state),
          // Tab 2 — Inventory (FIX H-10: forward custom dates)
          _InventoryTab(
            period: state.period,
            customStart: _customStart,
            customEnd: _customEnd,
          ),
          // Tab 3 — Customers (FIX H-10: forward custom dates)
          _CustomersTab(
            period: state.period,
            customStart: _customStart,
            customEnd: _customEnd,
          ),
          // Tab 4 — Financial (FIX H-10: forward custom dates)
          _FinancialTab(
            period: state.period,
            customStart: _customStart,
            customEnd: _customEnd,
          ),
          // Tab 5 — Staff
          _StaffTab(period: state.period),
          // Tab 6 — Export
          _ExportTab(),
        ],
      ),
    );
  }
}

// Helpers

typedef _DateRangeKey = ({String period, String? startDate, String? endDate});

/// Convert a DateTime to 'yyyy-MM-dd' string.
String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Build the family key used by inventorySummaryProvider, customersSummaryProvider,
/// and financialSummaryProvider. When custom dates are provided they take priority.
_DateRangeKey _rangeKey({
  required String period,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (customStart != null && customEnd != null) {
    return (
      period: period,
      startDate: _isoDate(customStart),
      endDate: _isoDate(customEnd),
    );
  }
  return (period: period, startDate: null, endDate: null);
}

// Tab 0: Overview

class _OverviewTab extends ConsumerWidget {
  final AnalyticsState state;
  const _OverviewTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(analyticsProvider.notifier).load(period: state.period),
      child: state.isLoading
          ? LayoutBuilder(
              builder: (_, c) => ShimmerKpiGrid(
                crossAxisCount: Responsive.gridCols(c.maxWidth,
                    phone: 2, tablet: 4, wide: 4),
              ),
            )
          : state.error != null
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(analyticsProvider.notifier).load(),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (state.kpi != null) ...[
                      _KpiGrid(kpi: state.kpi!),
                      const SizedBox(height: 8),
                    ],
                    if (state.salesPoints.isNotEmpty) ...[
                      _SalesLineChart(points: state.salesPoints),
                      const SizedBox(height: 8),
                    ],
                    if (state.topProducts.isNotEmpty)
                      _TopProductsCard(products: state.topProducts),
                  ],
                ),
    );
  }
}

// Tab 1: Sales

class _SalesTab extends ConsumerWidget {
  final AnalyticsState state;
  const _SalesTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(analyticsProvider.notifier).load(period: state.period),
      child: state.isLoading
          ? LayoutBuilder(
              builder: (_, c) => ShimmerKpiGrid(
                crossAxisCount: Responsive.gridCols(c.maxWidth,
                    phone: 2, tablet: 4, wide: 4),
              ),
            )
          : state.error != null
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(analyticsProvider.notifier).load(),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const SizedBox(height: 8),
                    if (state.salesPoints.isNotEmpty) ...[
                      _SalesBarChart(points: state.salesPoints),
                      const SizedBox(height: 8),
                    ],
                    if (state.topProducts.isNotEmpty)
                      _TopProductsTable(products: state.topProducts),
                  ],
                ),
    );
  }
}

// Tab 2: Inventory

class _InventoryTab extends ConsumerWidget {
  final String period;
  final DateTime? customStart;
  final DateTime? customEnd;
  const _InventoryTab({
    required this.period,
    this.customStart,
    this.customEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX H-10: forward customStart/customEnd to the provider key
    final key = _rangeKey(period: period, customStart: customStart, customEnd: customEnd);
    final async = ref.watch(inventorySummaryProvider(key));
    return async.when(
      loading: () => LayoutBuilder(
        builder: (_, c) => ShimmerKpiGrid(
          crossAxisCount:
              Responsive.gridCols(c.maxWidth, phone: 2, tablet: 4, wide: 4),
        ),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(inventorySummaryProvider(key)),
      ),
      data: (data) => _InventoryContent(data: data),
    );
  }
}

class _InventoryContent extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _InventoryContent({required this.data});

  @override
  ConsumerState<_InventoryContent> createState() => _InventoryContentState();
}

class _InventoryContentState extends ConsumerState<_InventoryContent> {
  int _deadStockDays = 30;

  @override
  Widget build(BuildContext context) {
    final totalSku = widget.data['total_skus'] as int? ?? 0;
    final lowStock = widget.data['low_stock_count'] as int? ?? 0;
    final outOfStock = widget.data['out_of_stock_count'] as int? ?? 0;
    final inventoryValue =
        (widget.data['inventory_value'] as num?)?.toDouble() ?? 0.0;

    final deadStockAsync = ref.watch(deadStockProvider(_deadStockDays));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // KPI cards
        LayoutBuilder(
          builder: (_, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: Responsive.gridCols(c.maxWidth,
                phone: 2, tablet: 4, wide: 4),
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _KpiCard(
                title: 'Total SKUs',
                value: totalSku.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppColors.info,
              ),
              _KpiCard(
                title: 'Low Stock',
                value: lowStock.toString(),
                icon: Icons.warning_amber_outlined,
                color: AppColors.warning,
              ),
              _KpiCard(
                title: 'Out of Stock',
                value: outOfStock.toString(),
                icon: Icons.remove_shopping_cart_outlined,
                color: AppColors.error,
              ),
              _KpiCard(
                title: 'Inventory Value',
                value: CurrencyFormatter.format(inventoryValue),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
        // Dead stock section header + days filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 15, color: Colors.amber),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'DEAD STOCK',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0),
                ),
              ),
              // Days filter chips
              ...([30, 60, 90]).map((d) {
                final isSelected = _deadStockDays == d;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _deadStockDays = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.amber.withValues(alpha: 0.18)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.amber
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        '${d}d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.amber.shade700
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // Dead stock list
        deadStockAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.toString(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.error)),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(deadStockProvider(_deadStockDays)),
                  child: const Text('Retry'),
                ),
              ]),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [
                  Icon(Icons.check_circle_outline,
                      size: 32,
                      color: AppColors.success.withValues(alpha: 0.7)),
                  const SizedBox(height: 8),
                  Text(
                    'No dead stock in the last $_deadStockDays days',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ]),
              );
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(children: const [
                      Expanded(
                          child: Text('Product',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary))),
                      SizedBox(
                          width: 52,
                          child: Text('Days',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary))),
                      SizedBox(
                          width: 52,
                          child: Text('Stock',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary))),
                    ]),
                  ),
                  // Rows
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isLast = idx == items.length - 1;
                    final name =
                        item['product_name'] as String? ?? 'Unknown';
                    final sku = item['sku'] as String? ?? '';
                    // FIX M-07: use correct field names from backend
                    final daysSince =
                        item['days_without_sale'] as int? ?? _deadStockDays;
                    final qty =
                        (item['quantity_on_hand'] as num?)?.toInt() ?? 0;
                    return Container(
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(
                                bottom: BorderSide(
                                    color: AppColors.divider,
                                    width: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary),
                                ),
                                if (sku.isNotEmpty)
                                  Text(
                                    sku,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '$daysSince',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade700),
                            ),
                          ),
                          SizedBox(
                            width: 52,
                            child: Text(
                              qty.toString(),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// Tab 3: Customers

class _CustomersTab extends ConsumerWidget {
  final String period;
  // FIX H-10: accept optional custom date range
  final DateTime? customStart;
  final DateTime? customEnd;
  const _CustomersTab({
    required this.period,
    this.customStart,
    this.customEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX H-10: forward custom dates to the provider key
    final key = _rangeKey(period: period, customStart: customStart, customEnd: customEnd);
    final async = ref.watch(customersSummaryProvider(key));
    return async.when(
      loading: () => LayoutBuilder(
        builder: (_, c) => ShimmerKpiGrid(
          crossAxisCount:
              Responsive.gridCols(c.maxWidth, phone: 2, tablet: 4, wide: 4),
        ),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(customersSummaryProvider(key)),
      ),
      data: (data) => _CustomersContent(data: data),
    );
  }
}

class _CustomersContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CustomersContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalCustomers = data['total_customers'] as int? ?? 0;
    final newThisPeriod = data['new_this_period'] as int? ?? 0;
    final returningRate =
        (data['returning_rate'] as num?)?.toDouble() ?? 0.0;
    final topCustomers =
        (data['top_customers'] as List<dynamic>?) ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        LayoutBuilder(
          builder: (_, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: Responsive.gridCols(c.maxWidth,
                phone: 2, tablet: 4, wide: 4),
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _KpiCard(
                title: 'Total Customers',
                value: totalCustomers.toString(),
                icon: Icons.people_outline,
                color: AppColors.primary,
              ),
              _KpiCard(
                title: 'New This Period',
                value: newThisPeriod.toString(),
                icon: Icons.person_add_outlined,
                color: AppColors.success,
              ),
              _KpiCard(
                title: 'Returning Rate',
                value: '${returningRate.toStringAsFixed(1)}%',
                icon: Icons.repeat_outlined,
                color: AppColors.info,
              ),
            ],
          ),
        ),
        if (topCustomers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: const Text(
              'TOP CUSTOMERS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0),
            ),
          ),
          ...topCustomers.take(5).map((c) {
            final cMap = c as Map<String, dynamic>;
            final name = cMap['name'] as String? ?? 'Unknown';
            final spent = (cMap['total_spent'] as num?)?.toDouble() ?? 0.0;
            final orders = cMap['order_count'] as int? ?? 0;
            return Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('$orders orders',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                trailing: Text(
                  CurrencyFormatter.format(spent),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// Tab 4: Financial

class _FinancialTab extends ConsumerWidget {
  final String period;
  // FIX H-10: accept optional custom date range
  final DateTime? customStart;
  final DateTime? customEnd;
  const _FinancialTab({
    required this.period,
    this.customStart,
    this.customEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX H-10: forward custom dates to the provider key
    final key = _rangeKey(period: period, customStart: customStart, customEnd: customEnd);
    final async = ref.watch(financialSummaryProvider(key));
    return async.when(
      loading: () => LayoutBuilder(
        builder: (_, c) => ShimmerKpiGrid(
          crossAxisCount:
              Responsive.gridCols(c.maxWidth, phone: 2, tablet: 4, wide: 4),
        ),
      ),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(financialSummaryProvider(key)),
      ),
      data: (data) => _FinancialContent(data: data),
    );
  }
}

class _FinancialContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FinancialContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final grossRevenue =
        (data['gross_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalCosts =
        (data['total_costs'] as num?)?.toDouble() ?? 0.0;
    final grossProfit =
        (data['gross_profit'] as num?)?.toDouble() ?? 0.0;
    final profitMargin =
        (data['profit_margin'] as num?)?.toDouble() ?? 0.0;
    final trendNote = data['trend_note'] as String?;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        LayoutBuilder(
          builder: (_, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: Responsive.gridCols(c.maxWidth,
                phone: 2, tablet: 4, wide: 4),
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _KpiCard(
                title: 'Gross Revenue',
                value: CurrencyFormatter.format(grossRevenue),
                icon: Icons.monetization_on_outlined,
                color: AppColors.primary,
              ),
              _KpiCard(
                title: 'Total Costs',
                value: CurrencyFormatter.format(totalCosts),
                icon: Icons.remove_circle_outline,
                color: AppColors.error,
              ),
              _KpiCard(
                title: 'Gross Profit',
                value: CurrencyFormatter.format(grossProfit),
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
              ),
              _KpiCard(
                title: 'Profit Margin',
                value: '${profitMargin.toStringAsFixed(1)}%',
                icon: Icons.percent_rounded,
                color: AppColors.info,
              ),
            ],
          ),
        ),
        if (trendNote != null && trendNote.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trendNote,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Tab 5: Staff

class _StaffTab extends ConsumerWidget {
  final String period;
  const _StaffTab({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffAnalyticsProvider(period));

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.refresh(_staffAnalyticsProvider(period).future),
      child: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
        data: (cashiers) {
          if (cashiers.isEmpty) {
            return const EmptyView(
              icon: Icons.people_outline,
              title: 'No Staff Data',
              subtitle: 'No cashier data for this period.',
            );
          }
          final totalOrders = cashiers.fold<int>(0, (s, c) => s + (c['orders'] as int? ?? 0));
          final totalSales  = cashiers.fold<double>(0, (s, c) => s + (c['sales'] as num? ?? 0).toDouble());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary chips
              Row(children: [
                _StatChip(label: 'Active Cashiers', value: cashiers.length.toString()),
                const SizedBox(width: 8),
                _StatChip(label: 'Total Orders', value: totalOrders.toString()),
                const SizedBox(width: 8),
                _StatChip(label: 'Total Sales', value: CurrencyFormatter.format(totalSales), accent: true),
              ]),
              const SizedBox(height: 16),
              // Cashier rows
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text('Cashier', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                      SizedBox(width: 60, child: Text('Orders', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                      SizedBox(width: 80, child: Text('Sales', style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.right)),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ...cashiers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    final isLast = i == cashiers.length - 1;
                    return Container(
                      decoration: BoxDecoration(
                        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            c['cashier_name'] as String? ?? 'Unknown',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                          )),
                          SizedBox(width: 60, child: Text(
                            '${c['orders'] ?? 0}',
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppColors.textPrimary),
                            textAlign: TextAlign.right,
                          )),
                          SizedBox(width: 80, child: Text(
                            CurrencyFormatter.format((c['sales'] as num? ?? 0).toDouble()),
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.primary),
                            textAlign: TextAlign.right,
                          )),
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _StatChip({required this.label, required this.value, this.accent = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent ? AppColors.primary : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

// Tab 6: Export

class _ExportTab extends StatelessWidget {
  const _ExportTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Download sales, inventory and financial reports as CSV files.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  context.push('/analytics/export'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Open Export Center',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// KPI Grid

class _KpiGrid extends StatelessWidget {
  final DashboardKpiModel kpi;
  const _KpiGrid({required this.kpi});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: Responsive.gridCols(c.maxWidth,
            phone: 2, tablet: 4, wide: 4),
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _KpiCard(
            title: 'Revenue',
            value: CurrencyFormatter.format(kpi.totalRevenue),
            icon: Icons.monetization_on_outlined,
            color: AppColors.primary,
            growth: kpi.revenueGrowth,
          ),
          _KpiCard(
            title: 'Orders',
            value: kpi.totalOrders.toString(),
            icon: Icons.receipt_long_outlined,
            color: AppColors.secondary,
            growth: kpi.orderGrowth,
          ),
          _KpiCard(
            title: 'Avg Order',
            value: CurrencyFormatter.format(kpi.averageOrderValue),
            icon: Icons.bar_chart_rounded,
            color: AppColors.info,
          ),
          _KpiCard(
            title: 'Customers',
            value: kpi.totalCustomers.toString(),
            icon: Icons.people_outline,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? growth;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.growth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary)),
              ),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: growth! >= 0
                        ? AppColors.successLight
                        : AppColors.errorLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${growth! >= 0 ? '+' : ''}${growth!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: growth! >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Revenue Line Chart (Overview)

class _SalesLineChart extends StatelessWidget {
  final List<SalesSummaryPoint> points;
  const _SalesLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final rawMaxY =
        points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);
    // FIX H-11: guard against zero maxY to prevent fl_chart assertion crash
    final safeMaxY = rawMaxY > 0 ? rawMaxY * 1.2 : 1.0;

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.revenue);
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, c) => SizedBox(
              height: c.maxWidth < 500 ? 150 : 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.divider,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox();
                          }
                          if (points.length <= 8 ||
                              idx % (points.length ~/ 4) == 0) {
                            final dt = points[idx].date;
                            return Text('${dt.day}/${dt.month}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary));
                          }
                          return const SizedBox();
                        },
                        reservedSize: 24,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: 0,
                  maxY: safeMaxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Sales Bar Chart (Sales Tab)

class _SalesBarChart extends StatelessWidget {
  final List<SalesSummaryPoint> points;
  const _SalesBarChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox();

    final rawMaxY =
        points.map((p) => p.revenue).reduce((a, b) => a > b ? a : b);
    // FIX H-11: guard against zero maxY to prevent fl_chart assertion crash
    final safeMaxY = rawMaxY > 0 ? rawMaxY * 1.2 : 1.0;

    // Show at most 14 bars to avoid clutter
    final display = points.length > 14
        ? points.sublist(points.length - 14)
        : points;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Revenue',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, c) => SizedBox(
              height: c.maxWidth < 500 ? 160 : 210,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: safeMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.divider,
                      strokeWidth: 0.5,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= display.length) {
                            return const SizedBox();
                          }
                          if (display.length <= 7 ||
                              idx % (display.length ~/ 4) == 0) {
                            final dt = display[idx].date;
                            return Text('${dt.day}/${dt.month}',
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary));
                          }
                          return const SizedBox();
                        },
                        reservedSize: 22,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: display.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.revenue,
                          color: AppColors.primary,
                          width: (c.maxWidth - 64) / display.length * 0.6,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Top Products Card

class _TopProductsCard extends StatelessWidget {
  final List<TopProductModel> products;
  const _TopProductsCard({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Products',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...products.take(10).toList().asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(p.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyFormatter.format(p.revenue),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      Text('${p.quantitySold} sold',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Top Products Table (Sales Tab)

class _TopProductsTable extends StatelessWidget {
  final List<TopProductModel> products;
  const _TopProductsTable({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Top Products by Revenue',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          // Header row
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.divider)),
            ),
            child: const Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text('#',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                Expanded(
                    child: Text('Product',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                SizedBox(
                    width: 60,
                    child: Text('Sold',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
                SizedBox(
                    width: 90,
                    child: Text('Revenue',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary))),
              ],
            ),
          ),
          ...products.take(10).toList().asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: i < products.take(10).length - 1
                    ? const Border(
                        bottom: BorderSide(color: AppColors.divider))
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: i < 3
                                ? AppColors.primary
                                : AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text(p.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary)),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(p.quantitySold.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(CurrencyFormatter.format(p.revenue),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
