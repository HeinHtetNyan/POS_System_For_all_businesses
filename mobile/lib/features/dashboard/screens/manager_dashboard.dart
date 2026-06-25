import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/notification_model.dart';
import '../../../models/order_model.dart';
import '../../../models/purchase_order_model.dart';
import '../../../models/user_model.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../orders/data/orders_repository.dart';
import '../../procurement/data/procurement_repository.dart';

class _BranchItem {
  final String id;
  final String name;
  final String? code;

  const _BranchItem({
    required this.id,
    required this.name,
    this.code,
  });
}

class _ManagerDashboardData {
  final Map<String, dynamic> kpis;
  final List<OrderModel> recentOrders;
  final List<NotificationModel> notifications;
  final List<Map<String, dynamic>> lowStock;
  final int pendingPurchaseOrders;
  final int approvedPurchaseOrders;
  final int partialPurchaseOrders;
  final List<PurchaseOrderModel> pendingPurchaseOrderItems;

  const _ManagerDashboardData({
    required this.kpis,
    required this.recentOrders,
    required this.notifications,
    required this.lowStock,
    required this.pendingPurchaseOrders,
    required this.approvedPurchaseOrders,
    required this.partialPurchaseOrders,
    required this.pendingPurchaseOrderItems,
  });
}

final _branchesProvider =
    FutureProvider.family<List<_BranchItem>, String>((ref, tenantId) async {
  final response = await apiClient.get(ApiEndpoints.branches(tenantId));
  final data = response.data;
  final rawItems = data is Map<String, dynamic>
      ? (data['items'] as List<dynamic>? ?? data['branches'] as List<dynamic>? ?? [])
      : (data as List<dynamic>? ?? []);

  return rawItems
      .map((item) => item as Map<String, dynamic>)
      .where((item) => (item['status'] as String? ?? 'ACTIVE') == 'ACTIVE')
      .map(
        (item) => _BranchItem(
          id: item['id'] as String? ?? '',
          name: item['name'] as String? ?? 'Branch',
          code: item['code'] as String?,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList();
});

final _managerDashboardProvider = FutureProvider.autoDispose
    .family<_ManagerDashboardData, ({String? branchId, bool canProcure})>((
      ref,
      params,
    ) async {
      final ordersRepo = ref.read(ordersRepositoryProvider);
      final notificationsRepo = ref.read(notificationsRepositoryProvider);
      final procurementRepo = ref.read(procurementRepositoryProvider);

      final queryParams = <String, dynamic>{
        if (params.branchId != null) 'branch_id': params.branchId,
      };

      final futures = await Future.wait<dynamic>([
        apiClient.dio.get(
          ApiEndpoints.analyticsDashboard,
          queryParameters: queryParams.isEmpty ? null : queryParams,
        ),
        apiClient.dio.get(
          '/analytics/inventory/low-stock',
          queryParameters: queryParams.isEmpty ? null : queryParams,
        ),
        ordersRepo.listOrders(
          branchId: params.branchId,
          page: 1,
          pageSize: 5,
        ),
        notificationsRepo.listNotifications(page: 1, pageSize: 5),
        if (params.canProcure)
          procurementRepo.listPurchaseOrders(
            status: 'APPROVED',
            page: 1,
            pageSize: 5,
          ),
        if (params.canProcure)
          procurementRepo.listPurchaseOrders(
            status: 'PARTIALLY_RECEIVED',
            page: 1,
            pageSize: 5,
          ),
      ]);

      final kpis = (futures[0] as dynamic).data as Map<String, dynamic>? ?? {};
      final lowStockRaw = (futures[1] as dynamic).data as List<dynamic>? ?? [];
      final recentOrders = (futures[2] as ({List<OrderModel> items, int total})).items;
      final notifications =
          (futures[3] as ({List<NotificationModel> items, int total})).items;

      var approvedTotal = 0;
      var partialTotal = 0;
      var pendingItems = <PurchaseOrderModel>[];

      if (params.canProcure) {
        final approved =
            futures[4] as ({List<PurchaseOrderModel> items, int total});
        final partial =
            futures[5] as ({List<PurchaseOrderModel> items, int total});
        approvedTotal = approved.total;
        partialTotal = partial.total;
        pendingItems = [
          ...approved.items,
          ...partial.items,
        ]..sort((a, b) {
            return b.orderDate.compareTo(a.orderDate);
          });
      }

      return _ManagerDashboardData(
        kpis: kpis,
        recentOrders: recentOrders,
        notifications: notifications,
        lowStock: lowStockRaw
            .map((item) => item as Map<String, dynamic>)
            .toList(),
        pendingPurchaseOrders: approvedTotal + partialTotal,
        approvedPurchaseOrders: approvedTotal,
        partialPurchaseOrders: partialTotal,
        pendingPurchaseOrderItems: pendingItems.take(5).toList(),
      );
    });

class ManagerDashboard extends ConsumerStatefulWidget {
  const ManagerDashboard({super.key});

  @override
  ConsumerState<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends ConsumerState<ManagerDashboard> {
  static const String _allBranches = '__all__';
  String? _selectedBranchId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final canSwitchBranches = user.isBusinessOwner || user.isManager;
    final tenantId = user.tenantId;
    final effectiveBranchId = _selectedBranchId == _allBranches
        ? null
        : (_selectedBranchId ?? user.primaryBranchId);
    final dashboardAsync = ref.watch(
      _managerDashboardProvider((
        branchId: effectiveBranchId,
        canProcure: user.canAccessProcurement,
      )),
    );

    final branchesAsync = canSwitchBranches && tenantId != null
        ? ref.watch(_branchesProvider(tenantId))
        : const AsyncValue<List<_BranchItem>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          if (tenantId != null && canSwitchBranches) {
            ref.invalidate(_branchesProvider(tenantId));
          }
          ref.invalidate(
            _managerDashboardProvider((
              branchId: effectiveBranchId,
              canProcure: user.canAccessProcurement,
            )),
          );
          await ref.read(
            _managerDashboardProvider((
              branchId: effectiveBranchId,
              canProcure: user.canAccessProcurement,
            )).future,
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHero(
                      user: user,
                      currentBranchName: branchesAsync.maybeWhen(
                        data: (branches) {
                          if (_selectedBranchId == _allBranches) {
                            return 'All Branches';
                          }
                          for (final branch in branches) {
                            if (branch.id == effectiveBranchId) {
                              return branch.name;
                            }
                          }
                          return null;
                        },
                        orElse: () => null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canSwitchBranches && tenantId != null)
                      _BranchSelector(
                        tenantId: tenantId,
                        selectedId: _selectedBranchId ?? user.primaryBranchId,
                        onSelect: (id) => setState(() => _selectedBranchId = id),
                      ),
                    if (canSwitchBranches && tenantId != null)
                      const SizedBox(height: 20),
                    dashboardAsync.when(
                      loading: _DashboardLoading.new,
                      error: (error, _) => _DashboardError(
                        message: error.toString(),
                        onRetry: () {
                          ref.invalidate(
                            _managerDashboardProvider((
                              branchId: effectiveBranchId,
                              canProcure: user.canAccessProcurement,
                            )),
                          );
                        },
                      ),
                      data: (data) => _DashboardContent(
                        data: data,
                        user: user,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final _ManagerDashboardData data;
  final UserModel user;

  const _DashboardContent({
    required this.data,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = user.isBusinessOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          eyebrow: 'TODAY\'S PERFORMANCE',
          title: 'Business Overview',
          subtitle: 'Sales, inventory, and customer metrics at a glance.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = Responsive.gridCols(
              constraints.maxWidth,
              phone: 2,
              tablet: 2,
              wide: 4,
            );
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 840 ? 1.5 : 1.15,
              children: [
                _KpiCard(
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.primary,
                  label: 'Revenue Today',
                  value: _formatMoney(data.kpis['revenue_today']),
                  subtitle: '${_asInt(data.kpis['orders_today'])} orders',
                  accent: true,
                ),
                _KpiCard(
                  icon: Icons.show_chart,
                  iconColor: AppColors.info,
                  label: 'Month Revenue',
                  value: _formatMoney(data.kpis['revenue_month']),
                  subtitle:
                      '${_asInt(data.kpis['orders_this_month'])} orders',
                ),
                _KpiCard(
                  icon: Icons.warehouse_outlined,
                  iconColor: AppColors.warning,
                  label: 'Inventory Value',
                  value: _formatMoney(data.kpis['inventory_value']),
                  subtitle: 'total valuation',
                ),
                _KpiCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.error,
                  label: 'Low Stock',
                  value: _asInt(data.kpis['low_stock_products']).toString(),
                  subtitle: _asInt(data.kpis['low_stock_products']) == 0
                      ? 'no alerts'
                      : 'products need restock',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = Responsive.gridCols(
              constraints.maxWidth,
              phone: 2,
              tablet: 2,
              wide: 4,
            );
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 840 ? 1.5 : 1.15,
              children: [
                _KpiCard(
                  icon: Icons.people_outline,
                  iconColor: AppColors.success,
                  label: 'Total Customers',
                  value: _asInt(data.kpis['total_customers']).toString(),
                  subtitle:
                      '+${_asInt(data.kpis['new_customers_month'])} this month',
                ),
                _KpiCard(
                  icon: Icons.keyboard_return_rounded,
                  iconColor: AppColors.secondary,
                  label: 'Refunds (Month)',
                  value:
                      _asInt(data.kpis['refund_count_month']).toString(),
                  subtitle: _formatMoney(data.kpis['refund_amount_month']),
                ),
                if (user.canAccessProcurement)
                  _KpiCard(
                    icon: Icons.shopping_cart_checkout_outlined,
                    iconColor: AppColors.info,
                    label: 'Pending POs',
                    value: data.pendingPurchaseOrders.toString(),
                    subtitle:
                        'Ordered ${data.approvedPurchaseOrders} · Partial ${data.partialPurchaseOrders}',
                  ),
                _KpiCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppColors.warning,
                  label: 'Customer Debts',
                  value: _formatMoney(
                    data.kpis['total_customer_outstanding'],
                  ),
                  subtitle: 'total outstanding balance',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          eyebrow: 'QUICK ACTIONS',
          title: 'Jump Back Into Work',
          subtitle: isOwner
              ? 'Navigate to any part of your business.'
              : 'Operational shortcuts for day-to-day management.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: Responsive.gridCols(
                constraints.maxWidth,
                phone: 2,
                tablet: 3,
                wide: 4,
              ),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: constraints.maxWidth >= 840 ? 1.45 : 1.2,
              children: [
                _QuickActionCard(
                  icon: Icons.point_of_sale_rounded,
                  iconColor: AppColors.primary,
                  label: 'New Sale',
                  description: 'Open POS checkout',
                  onTap: () => context.go('/pos'),
                ),
                _QuickActionCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.warning,
                  label: 'Inventory',
                  description: 'Review stock levels',
                  onTap: () => context.push('/inventory'),
                ),
                _QuickActionCard(
                  icon: Icons.local_shipping_outlined,
                  iconColor: AppColors.info,
                  label: 'Procurement',
                  description: 'Purchase orders and payables',
                  onTap: () => context.push('/procurement'),
                ),
                _QuickActionCard(
                  icon: Icons.people_outline,
                  iconColor: AppColors.success,
                  label: 'Customers',
                  description: 'Accounts and balances',
                  onTap: () => context.push('/customers'),
                ),
                _QuickActionCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: AppColors.secondary,
                  label: 'Analytics',
                  description: 'Business performance',
                  onTap: () => context.push('/analytics'),
                ),
                _QuickActionCard(
                  icon: Icons.notifications_none_rounded,
                  iconColor: AppColors.warning,
                  label: 'Notifications',
                  description: 'Unread alerts and updates',
                  onTap: () => context.push('/notifications'),
                ),
                if (isOwner)
                  _QuickActionCard(
                    icon: Icons.inventory_outlined,
                    iconColor: AppColors.primary,
                    label: 'Products',
                    description: 'Catalog and pricing',
                    onTap: () => context.push('/products'),
                  ),
                if (isOwner)
                  _QuickActionCard(
                    icon: Icons.settings_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Settings',
                    description: 'Business preferences',
                    onTap: () => context.push('/settings'),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ActivitySection(
                      title: 'Recent Sales',
                      actionLabel: 'View all',
                      onAction: () => context.push('/orders'),
                      children: data.recentOrders.isEmpty
                          ? const [_EmptySection(message: 'No orders yet today')]
                          : data.recentOrders
                              .map(
                                (order) => _ActivityTile(
                                  icon: Icons.receipt_long_outlined,
                                  iconColor: AppColors.primary,
                                  title: 'Order #${order.orderNumber}',
                                  subtitle:
                                      '${_formatMoney(order.netTotal)} · ${_titleCase(order.orderStatus)}',
                                  trailing: _relativeTime(order.createdAt),
                                  onTap: () => context.push('/orders'),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ActivitySection(
                      title: 'Recent Notifications',
                      actionLabel: 'View all',
                      onAction: () => context.push('/notifications'),
                      children: data.notifications.isEmpty
                          ? const [_EmptySection(message: 'No notifications')]
                          : data.notifications
                              .map(
                                (item) => _ActivityTile(
                                  icon: item.isUnread
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_none_outlined,
                                  iconColor: item.isUnread
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                                  title: item.title,
                                  subtitle: item.message,
                                  trailing: _relativeTime(item.createdAt),
                                  onTap: () => context.push('/notifications'),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                _ActivitySection(
                  title: 'Recent Sales',
                  actionLabel: 'View all',
                  onAction: () => context.push('/orders'),
                  children: data.recentOrders.isEmpty
                      ? const [_EmptySection(message: 'No orders yet today')]
                      : data.recentOrders
                          .map(
                            (order) => _ActivityTile(
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.primary,
                              title: 'Order #${order.orderNumber}',
                              subtitle:
                                  '${_formatMoney(order.netTotal)} · ${_titleCase(order.orderStatus)}',
                              trailing: _relativeTime(order.createdAt),
                              onTap: () => context.push('/orders'),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                _ActivitySection(
                  title: 'Recent Notifications',
                  actionLabel: 'View all',
                  onAction: () => context.push('/notifications'),
                  children: data.notifications.isEmpty
                      ? const [_EmptySection(message: 'No notifications')]
                      : data.notifications
                          .map(
                            (item) => _ActivityTile(
                              icon: item.isUnread
                                  ? Icons.notifications_active_outlined
                                  : Icons.notifications_none_outlined,
                              iconColor: item.isUnread
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              title: item.title,
                              subtitle: item.message,
                              trailing: _relativeTime(item.createdAt),
                              onTap: () => context.push('/notifications'),
                            ),
                          )
                          .toList(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        if (data.lowStock.isNotEmpty) ...[
          _SectionTitle(
            eyebrow: 'INVENTORY ALERTS',
            title: 'Low Stock Alerts',
            subtitle: 'Products below reorder point that need restocking.',
          ),
          const SizedBox(height: 12),
          _ActivitySection(
            title: 'Products Needing Restock',
            actionLabel: 'Manage inventory',
            onAction: () => context.push('/inventory'),
            children: data.lowStock
                .take(8)
                .map(
                  (item) => _LowStockTile(
                    productName: item['product_name'] as String? ?? 'Product',
                    branchName: item['branch_name'] as String? ?? 'Branch',
                    sku: item['sku'] as String?,
                    quantityOnHand: item['quantity_on_hand']?.toString() ?? '0',
                    reorderPoint: item['reorder_point']?.toString() ?? '0',
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        if (user.canAccessProcurement && data.pendingPurchaseOrderItems.isNotEmpty)
          _ActivitySection(
            title: 'Pending Purchase Orders',
            actionLabel: 'View all',
            onAction: () => context.push('/procurement'),
            children: data.pendingPurchaseOrderItems
                .map(
                  (item) => _ActivityTile(
                    icon: Icons.assignment_outlined,
                    iconColor: AppColors.info,
                    title: 'PO ${item.orderNumber}',
                    subtitle:
                        '${_formatMoney(item.totalAmount)} · ${_titleCase(item.status)}',
                    trailing: _relativeTime(item.orderDate),
                    onTap: () => context.push('/procurement'),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final UserModel user;
  final String? currentBranchName;

  const _DashboardHero({
    required this.user,
    this.currentBranchName,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();
    final subtitle = user.isBusinessOwner ? 'Business overview' : 'Manager dashboard';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              user.isBusinessOwner
                  ? Icons.business_center_outlined
                  : Icons.manage_accounts_outlined,
              color: AppColors.primaryFg,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good $greeting, ${user.firstName.isEmpty ? 'there' : user.firstName}',
                  style: const TextStyle(
                    color: AppColors.primaryFg,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentBranchName == null
                      ? subtitle
                      : '$subtitle · $currentBranchName',
                  style: const TextStyle(
                    color: AppColors.primaryFg,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchSelector extends ConsumerWidget {
  final String tenantId;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _BranchSelector({
    required this.tenantId,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBranches = ref.watch(_branchesProvider(tenantId));

    return asyncBranches.when(
      loading: () => const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BRANCH VIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BranchChip(
                    label: 'All Branches',
                    selected: selectedId == _ManagerDashboardState._allBranches,
                    onTap: () => onSelect(_ManagerDashboardState._allBranches),
                  ),
                  ...branches.map(
                    (branch) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _BranchChip(
                        label: branch.name,
                        selected: selectedId == branch.id,
                        onTap: () => onSelect(branch.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BranchChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BranchChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.14) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;
  final bool accent;

  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent ? AppColors.primary.withValues(alpha: 0.35) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (accent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const Spacer(),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> children;

  const _ActivitySection({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.children,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...children,
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  final String productName;
  final String branchName;
  final String? sku;
  final String quantityOnHand;
  final String reorderPoint;

  const _LowStockTile({
    required this.productName,
    required this.branchName,
    this.sku,
    required this.quantityOnHand,
    required this.reorderPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sku == null || sku!.isEmpty
                      ? branchName
                      : 'SKU: $sku · $branchName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quantityOnHand,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'reorder at $reorderPoint',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 140,
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load dashboard',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryFg,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 17) return 'afternoon';
  return 'evening';
}

String _formatMoney(dynamic value) {
  return CurrencyFormatter.format(_asDouble(value));
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split('_')
      .map((part) {
        if (part.isEmpty) return part;
        return '${part[0]}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String _relativeTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
