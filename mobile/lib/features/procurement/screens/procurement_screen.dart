import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/procurement_repository.dart';
import '../providers/procurement_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'goods_receipt_detail_screen.dart';
import 'procurement_detail_screen.dart';
import 'procurement_form_screen.dart';
import 'suppliers_screen.dart';
import 'supplier_payables_screen.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/purchase_order_model.dart';

class _ProcurementDashboardData {
  final int orderedCount;
  final int partialReceiptCount;
  final int openPayablesCount;
  final int awaitingPaymentCount;
  final List<PurchaseOrderModel> recentOrders;
  final List<Map<String, dynamic>> recentReceipts;
  final List<Map<String, dynamic>> recentPayables;

  const _ProcurementDashboardData({
    required this.orderedCount,
    required this.partialReceiptCount,
    required this.openPayablesCount,
    required this.awaitingPaymentCount,
    required this.recentOrders,
    required this.recentReceipts,
    required this.recentPayables,
  });
}

final _procurementDashboardProvider =
    FutureProvider.autoDispose<_ProcurementDashboardData>((ref) async {
  final repo = ref.watch(procurementRepositoryProvider);
  final ordered =
      await repo.listPurchaseOrders(status: 'APPROVED', pageSize: 1);
  final partialReceipt =
      await repo.listPurchaseOrders(status: 'PARTIALLY_RECEIVED', pageSize: 1);
  final openPayables = await repo.listPayables(status: 'OPEN', pageSize: 1);
  final awaitingPayment =
      await repo.listPayables(status: 'PARTIAL', pageSize: 1);
  final recentOrders = await repo.listPurchaseOrders(pageSize: 5);
  final recentReceipts = await repo.listGoodsReceipts(pageSize: 5);
  final recentPayables = await repo.listPayables(pageSize: 5);
  return _ProcurementDashboardData(
    orderedCount: ordered.total,
    partialReceiptCount: partialReceipt.total,
    openPayablesCount: openPayables.total,
    awaitingPaymentCount: openPayables.total + awaitingPayment.total,
    recentOrders: recentOrders.items,
    recentReceipts: recentReceipts.items,
    recentPayables: recentPayables.items,
  );
});

class ProcurementScreen extends ConsumerStatefulWidget {
  const ProcurementScreen({super.key});

  @override
  ConsumerState<ProcurementScreen> createState() => _ProcurementScreenState();
}

class _ProcurementScreenState extends ConsumerState<ProcurementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(procurementProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(procurementProvider.notifier).loadMore();
    }
  }

  void _openCreate() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ProcurementFormScreen(),
        fullscreenDialog: true,
      ));

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(procurementProvider);
    final dashboardAsync = ref.watch(_procurementDashboardProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.canAccessProcurement ?? false;
    final statuses = [null, 'DRAFT', 'ORDERED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED'];
    final statusLabels = ['All', 'Draft', 'Ordered', 'Partial', 'Received', 'Cancelled'];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryFg,
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Procurement',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview tab
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              await ref.read(procurementProvider.notifier).load(refresh: true);
              ref.invalidate(_procurementDashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                const Text(
                  'Procurement Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                dashboardAsync.when(
                  loading: () => const _DashboardLoading(),
                  error: (e, _) => _DashboardError(
                    message: e.toString(),
                    onRetry: () =>
                        ref.invalidate(_procurementDashboardProvider),
                  ),
                  data: (dashboard) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WebParityKpiGrid(data: dashboard),
                      const SizedBox(height: 20),

                      // Quick actions
                      const Text(
                        'QUICK ACTIONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (canCreate)
                            Expanded(
                              child: _QuickActionCard(
                                icon: Icons.add_circle_outline,
                                label: 'New Order',
                                color: AppColors.primary,
                                onTap: _openCreate,
                              ),
                            ),
                          if (canCreate) const SizedBox(width: 10),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.business_outlined,
                              label: 'Suppliers',
                              color: AppColors.info,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SuppliersScreen())),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.account_balance_outlined,
                              label: 'Payables',
                              color: AppColors.warning,
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const SupplierPayablesScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _OverviewSection<PurchaseOrderModel>(
                        title: 'Recent Purchase Orders',
                        emptyText: 'No purchase orders yet',
                        actionLabel: 'View all',
                        onAction: () => _tabController.animateTo(1),
                        items: dashboard.recentOrders,
                        itemBuilder: (po) => _POCard(
                          po: po,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProcurementDetailScreen(orderId: po.id),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _OverviewSection<Map<String, dynamic>>(
                        title: 'Recent Goods Receipts',
                        emptyText: 'No receipts yet',
                        actionLabel: 'Orders',
                        onAction: () => _tabController.animateTo(1),
                        items: dashboard.recentReceipts,
                        itemBuilder: (receipt) =>
                            _ReceiptCard(receipt: receipt),
                      ),
                      const SizedBox(height: 16),
                      _OverviewSection<Map<String, dynamic>>(
                        title: 'Outstanding Payables',
                        emptyText: 'No payables yet',
                        actionLabel: 'View all',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupplierPayablesScreen(),
                          ),
                        ),
                        items: dashboard.recentPayables,
                        itemBuilder: (payable) =>
                            _PayableCard(payable: payable),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Orders tab
          Column(
            children: [
              // Status filter chips
              Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    Container(height: 1, color: AppColors.divider),
                    SizedBox(
                      height: 48,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        itemCount: statuses.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StatusChip(
                            label: statusLabels[i],
                            selected: state.statusFilter == statuses[i],
                            onTap: () => ref
                                .read(procurementProvider.notifier)
                                .filterStatus(statuses[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () => ref
                      .read(procurementProvider.notifier)
                      .load(refresh: true),
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        )
                      : state.error != null
                          ? ErrorView(
                              message: state.error!,
                              onRetry: () => ref
                                  .read(procurementProvider.notifier)
                                  .load(refresh: true),
                            )
                          : state.items.isEmpty
                              ? const EmptyView(
                                  icon: Icons.local_shipping_outlined,
                                  title: 'No purchase orders',
                                  subtitle:
                                      'Create purchase orders to manage procurement',
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 96),
                                  itemCount: state.items.length +
                                      (state.isLoadingMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i >= state.items.length) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                              color: AppColors.primary),
                                        ),
                                      );
                                    }
                                    return _POCard(
                                      po: state.items[i],
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ProcurementDetailScreen(
                                                  orderId: state.items[i].id),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorView(message: message, onRetry: onRetry);
  }
}

class _WebParityKpiGrid extends StatelessWidget {
  final _ProcurementDashboardData data;

  const _WebParityKpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _KpiCard(
              label: 'Ordered',
              value: data.orderedCount.toString(),
              icon: Icons.receipt_long_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Partial Receipt',
              value: data.partialReceiptCount.toString(),
              icon: Icons.inventory_2_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _KpiCard(
              label: 'Open Payables',
              value: data.openPayablesCount.toString(),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            _KpiCard(
              label: 'Awaiting Payment',
              value: data.awaitingPaymentCount.toString(),
              icon: Icons.payments_outlined,
              color: AppColors.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewSection<T> extends StatelessWidget {
  final String title;
  final String emptyText;
  final String actionLabel;
  final VoidCallback onAction;
  final List<T> items;
  final Widget Function(T item) itemBuilder;

  const _OverviewSection({
    required this.title,
    required this.emptyText,
    required this.actionLabel,
    required this.onAction,
    required this.items,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...items.map(itemBuilder),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptCard({required this.receipt});

  String _date(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = raw is DateTime ? raw : DateTime.parse(raw.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (receipt['status'] ?? 'PENDING').toString();
    final receiptId = (receipt['id'] ?? '').toString();
    final receiptNumber = (receipt['receipt_number'] ?? receiptId).toString();
    return ListTile(
      onTap: receiptId.isEmpty
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GoodsReceiptDetailScreen(receiptId: receiptId),
                ),
              ),
      leading: const Icon(Icons.inventory_2_outlined, color: AppColors.info),
      title: Text(
        receiptNumber,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        _date(receipt['receipt_date'] ?? receipt['created_at']),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: StatusBadge(status: status),
    );
  }
}

class _PayableCard extends StatelessWidget {
  final Map<String, dynamic> payable;

  const _PayableCard({required this.payable});

  @override
  Widget build(BuildContext context) {
    final status = (payable['status'] ?? 'OPEN').toString();
    final total = (payable['total_amount'] as num?)?.toDouble() ?? 0;
    final remaining = (payable['remaining_amount'] as num?)?.toDouble() ?? 0;
    final supplierName =
        (payable['supplier_name'] ?? payable['purchase_order_ref'] ?? 'Payable')
            .toString();
    return ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SupplierPayablesScreen(),
        ),
      ),
      leading: const Icon(Icons.account_balance_wallet_outlined,
          color: AppColors.warning),
      title: Text(
        supplierName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        'Total ${CurrencyFormatter.format(total)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(remaining),
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Quick action card

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status filter chip

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// PO card

class _POCard extends StatelessWidget {
  final PurchaseOrderModel po;
  final VoidCallback? onTap;
  const _POCard({required this.po, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                  Expanded(
                    child: Text(
                      po.orderNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusBadge(status: po.status),
                ],
              ),
              if (po.supplierName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.business_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      po.supplierName!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        _fmt(po.orderDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (po.items.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.inventory_2_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${po.items.length} item${po.items.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(po.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
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

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
