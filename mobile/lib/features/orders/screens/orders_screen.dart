import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/orders_repository.dart';
import '../providers/orders_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../models/order_model.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(ordersProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(ordersProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    final statuses = [null, 'COMPLETED', 'VOIDED', 'PENDING'];
    final statusLabels = ['All', 'Completed', 'Voided', 'Pending'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Refunds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Orders tab
          Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by order number...',
                          hintStyle: const TextStyle(
                              color: AppColors.textDisabled, fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              size: 20,
                              color: AppColors.textSecondary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(ordersProvider.notifier)
                                        .search('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {});
                          ref.read(ordersProvider.notifier).search(v);
                        },
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: statuses.length,
                        itemBuilder: (_, i) {
                          final isSelected =
                              state.statusFilter == statuses[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: statusLabels[i],
                              selected: isSelected,
                              onSelected: (_) => ref
                                  .read(ordersProvider.notifier)
                                  .setFilter(statuses[i]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Stats row
              if (!state.isLoading && state.error == null && state.items.isNotEmpty)
                _StatsRow(orders: state.items),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(ordersProvider.notifier).load(refresh: true),
                  child: state.isLoading
                      ? const ShimmerList(itemHeight: 92)
                      : state.error != null
                          ? ErrorView(
                              message: state.error!,
                              onRetry: () => ref
                                  .read(ordersProvider.notifier)
                                  .load(refresh: true),
                            )
                          : state.items.isEmpty
                              ? const EmptyView(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No orders found',
                                  subtitle:
                                      'Orders will appear here after checkout',
                                )
                              : Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxWidth: 900),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                          bottom: 16),
                                      itemCount: state.items.length +
                                          (state.isLoadingMore ? 1 : 0),
                                      itemBuilder: (_, i) {
                                        if (i >= state.items.length) {
                                          return const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child:
                                                  CircularProgressIndicator(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          );
                                        }
                                        return _OrderCard(
                                          order: state.items[i],
                                          onTap: () => context.push(
                                              '/orders/${state.items[i].id}'),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                ),
              ),
            ],
          ),

          // Refunds tab
          const _RefundsTab(),
        ],
      ),
    );
  }
}

// Stats row (computed from loaded orders)

class _StatsRow extends StatelessWidget {
  final List<OrderModel> orders;

  const _StatsRow({required this.orders});

  @override
  Widget build(BuildContext context) {
    final completedOrders =
        orders.where((o) => o.orderStatus == 'COMPLETED').toList();
    final revenue =
        completedOrders.fold<double>(0, (sum, o) => sum + o.netTotal);
    final avgOrderValue =
        completedOrders.isEmpty ? 0.0 : revenue / completedOrders.length;

    final isTablet = MediaQuery.of(context).size.width >= 600;

    final cards = [
      _StatCardData(
        label: 'Loaded Orders',
        value: '${orders.length}',
        icon: Icons.receipt_long_outlined,
        accentColor: AppColors.textPrimary,
        iconBg: AppColors.surfaceVariant,
        iconColor: AppColors.textSecondary,
      ),
      _StatCardData(
        label: 'Revenue',
        value: CurrencyFormatter.format(revenue),
        icon: Icons.monetization_on_outlined,
        accentColor: AppColors.primary,
        iconBg: const Color(0xFF2D1F00), // dark amber tint
        iconColor: AppColors.primary,
      ),
      _StatCardData(
        label: 'Avg Order Value',
        value: CurrencyFormatter.format(avgOrderValue),
        icon: Icons.trending_up_outlined,
        accentColor: AppColors.primary,
        iconBg: const Color(0xFF2D1F00),
        iconColor: AppColors.primary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: isTablet
          ? Row(
              children: cards
                  .map((d) => Expanded(
                        child: Padding(
                          padding: cards.indexOf(d) < cards.length - 1
                              ? const EdgeInsets.only(right: 8)
                              : EdgeInsets.zero,
                          child: _StatCard(data: d),
                        ),
                      ))
                  .toList(),
            )
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: cards.map((d) => _StatCard(data: d)).toList(),
            ),
    );
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color iconBg;
  final Color iconColor;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.iconBg,
    required this.iconColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant, // dark zinc-800
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, size: 18, color: data.iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: data.accentColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Refunds tab

class _RefundsTab extends ConsumerStatefulWidget {
  const _RefundsTab();

  @override
  ConsumerState<_RefundsTab> createState() => _RefundsTabState();
}

class _RefundsTabState extends ConsumerState<_RefundsTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _refunds = [];
  bool _isLoading = true;
  String? _error;
  final _refundSearchController = TextEditingController();
  String _refundSearch = '';
  final _scrollController = ScrollController();

  // Pagination state
  int _page = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _refundSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final data = await ref
          .read(ordersRepositoryProvider)
          .listRefunds(page: 1, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _refunds = data;
          _isLoading = false;
          _hasMore = data.length >= _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = await ref
          .read(ordersRepositoryProvider)
          .listRefunds(page: nextPage, pageSize: _pageSize);
      if (mounted) {
        setState(() {
          _refunds = [..._refunds, ...data];
          _page = nextPage;
          _hasMore = data.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) return const ShimmerList(itemHeight: 80);
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_refunds.isEmpty) {
      return const EmptyView(
        icon: Icons.undo_outlined,
        title: 'No refunds',
        subtitle: 'Processed refunds will appear here',
      );
    }

    final q = _refundSearch.toLowerCase().trim();
    final filtered = q.isEmpty
        ? _refunds
        : _refunds.where((r) {
            return r['order_number']?.toString().toLowerCase().contains(q) == true ||
                r['refund_number']?.toString().toLowerCase().contains(q) == true ||
                r['reason']?.toString().toLowerCase().contains(q) == true;
          }).toList();

    final totalAmount = _refunds.fold<double>(
        0,
        (sum, r) =>
            sum + ((r['refund_amount'] as num?)?.toDouble() ?? 0));
    final avgRefund =
        _refunds.isEmpty ? 0.0 : totalAmount / _refunds.length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _refundSearchController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by order number or reason...',
                    hintStyle: const TextStyle(
                        color: AppColors.textDisabled, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: AppColors.textSecondary),
                    suffixIcon: _refundSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              _refundSearchController.clear();
                              setState(() => _refundSearch = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (v) => setState(() => _refundSearch = v),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    _RefundsStatsRow(
                      count: _refunds.length,
                      totalAmount: totalAmount,
                      avgRefund: avgRefund,
                    ),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: EmptyView(
                          icon: Icons.search_off_outlined,
                          title: 'No results',
                          subtitle: 'No refunds match your search',
                        ),
                      )
                    else
                      ...filtered.map((r) => _RefundCard(refund: r)),
                    if (_isLoadingMore)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Refunds stats row

class _RefundsStatsRow extends StatelessWidget {
  final int count;
  final double totalAmount;
  final double avgRefund;

  const _RefundsStatsRow({
    required this.count,
    required this.totalAmount,
    required this.avgRefund,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final cards = [
      _StatCardData(
        label: 'Total Refunds',
        value: '$count',
        icon: Icons.undo_outlined,
        accentColor: AppColors.textPrimary,
        iconBg: AppColors.surfaceVariant,
        iconColor: AppColors.textSecondary,
      ),
      _StatCardData(
        label: 'Refunded Total',
        value: CurrencyFormatter.format(totalAmount),
        icon: Icons.money_off_outlined,
        accentColor: AppColors.error,
        iconBg: AppColors.errorLight,
        iconColor: AppColors.error,
      ),
      _StatCardData(
        label: 'Avg Refund',
        value: CurrencyFormatter.format(avgRefund),
        icon: Icons.analytics_outlined,
        accentColor: AppColors.primary,
        iconBg: const Color(0xFF2D1F00),
        iconColor: AppColors.primary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: isTablet
          ? Row(
              children: cards
                  .map((d) => Expanded(
                        child: Padding(
                          padding: cards.indexOf(d) < cards.length - 1
                              ? const EdgeInsets.only(right: 8)
                              : EdgeInsets.zero,
                          child: _StatCard(data: d),
                        ),
                      ))
                  .toList(),
            )
          : GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: cards.map((d) => _StatCard(data: d)).toList(),
            ),
    );
  }
}


class _RefundCard extends StatelessWidget {
  final Map<String, dynamic> refund;
  const _RefundCard({required this.refund});

  @override
  Widget build(BuildContext context) {
    final orderNum = refund['order_number'] as String? ?? '—';
    final amount = (refund['refund_amount'] as num?)?.toDouble() ?? 0;
    final method = refund['refund_method'] as String? ?? '—';
    final status = refund['refund_status'] as String? ?? '—';
    final rawDate = refund['created_at'] as String?;
    DateTime? date;
    if (rawDate != null) {
      try {
        date = DateTime.parse(rawDate);
      } catch (_) {}
    }

    final Color statusColor;
    final Color statusBg;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        break;
      case 'PENDING':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        break;
      case 'REJECTED':
      case 'FAILED':
        statusColor = AppColors.error;
        statusBg = AppColors.errorLight;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusBg = AppColors.surfaceVariant;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.undo_outlined,
                color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order $orderNum',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(method,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    if (date != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/'
                        '${date.year}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(amount),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.error),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Reusable dark filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color:
                selected ? AppColors.primaryFg : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Order card
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.orderNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _OrderStatusBadge(status: order.orderStatus),
                  const SizedBox(width: 6),
                  _PaymentStatusBadge(status: order.paymentStatus),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(order.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (order.customerName != null) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.customerName!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    CurrencyFormatter.format(order.netTotal),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// Order status badge
class _OrderStatusBadge extends StatelessWidget {
  final String status;

  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'VOIDED':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      case 'PENDING':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'PARTIALLY_REFUNDED':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        status == 'PARTIALLY_REFUNDED' ? 'Partially Refunded' : status,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// Payment status badge
class _PaymentStatusBadge extends StatelessWidget {
  final String status;

  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    switch (status.toUpperCase()) {
      case 'PAID':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'UNPAID':
      case 'FAILED':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      case 'PARTIAL':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'REFUNDED':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
