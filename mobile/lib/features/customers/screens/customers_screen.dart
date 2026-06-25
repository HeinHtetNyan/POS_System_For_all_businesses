import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/customers_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../models/customer_model.dart';
import '../../../models/user_model.dart';
import '../../../core/providers/auth_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customersProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(customersProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate =
        user?.role != UserRole.cashier && user?.role != UserRole.inventoryStaff;
    final activeFilter = state.activeFilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, code...',
                    hintStyle: const TextStyle(
                        color: AppColors.textDisabled, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(customersProvider.notifier).search('');
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
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    ref.read(customersProvider.notifier).search(v);
                  },
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _ActiveChip(
                      label: 'All',
                      selected: activeFilter == null,
                      onTap: () => ref
                          .read(customersProvider.notifier)
                          .filterActive(null),
                    ),
                    const SizedBox(width: 8),
                    _ActiveChip(
                      label: 'Active',
                      selected: activeFilter == true,
                      color: AppColors.success,
                      onTap: () => ref
                          .read(customersProvider.notifier)
                          .filterActive(true),
                    ),
                    const SizedBox(width: 8),
                    _ActiveChip(
                      label: 'Inactive',
                      selected: activeFilter == false,
                      color: AppColors.textSecondary,
                      onTap: () => ref
                          .read(customersProvider.notifier)
                          .filterActive(false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryFg,
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(customersProvider.notifier).load(refresh: true),
        child: state.isLoading
            ? const ShimmerList(itemHeight: 72)
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => ref.read(customersProvider.notifier).load(refresh: true),
                  )
                : state.items.isEmpty
                    ? EmptyView(
                        icon: Icons.people_outline,
                        title: 'No customers yet',
                        subtitle: 'Add your first customer',
                        action: canCreate
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.primaryFg,
                                ),
                                onPressed: () => _showCreateDialog(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Customer'),
                              )
                            : null,
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: state.items.length +
                                (state.isLoadingMore ? 1 : 0) +
                                1, // +1 for stats header
                            itemBuilder: (_, i) {
                              // First item: stats widget
                              if (i == 0) {
                                return _CustomerStats(customers: state.items);
                              }
                              final itemIndex = i - 1;
                              if (itemIndex >= state.items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }
                              return _CustomerTile(
                                customer: state.items[itemIndex],
                                onTap: () => context.go(
                                  '/customers/${state.items[itemIndex].id}',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    context.go('/customers/new');
  }
}

// Customer stats
class _CustomerStats extends StatelessWidget {
  final List<CustomerModel> customers;

  const _CustomerStats({required this.customers});

  @override
  Widget build(BuildContext context) {
    final total = customers.length;
    final active = customers.where((c) => c.isActive).length;
    final withBalance = customers.where((c) => c.currentBalance > 0).length;
    final outstanding = customers.fold<double>(
      0.0,
      (sum, c) => sum + (c.currentBalance > 0 ? c.currentBalance : 0.0),
    );

    final isTablet = MediaQuery.of(context).size.width >= 600;

    final cards = [
      _StatCard(
        label: 'Total',
        value: '$total',
        icon: Icons.people_outline,
        iconColor: AppColors.textSecondary,
        bgColor: AppColors.surfaceVariant,
        borderColor: AppColors.divider,
        valueColor: AppColors.textPrimary,
      ),
      _StatCard(
        label: 'Active',
        value: '$active',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        bgColor: AppColors.successLight,
        borderColor: AppColors.success.withValues(alpha: 0.3),
        valueColor: AppColors.success,
      ),
      _StatCard(
        label: 'With Balance',
        value: '$withBalance',
        icon: Icons.account_balance_wallet_outlined,
        iconColor: AppColors.info,
        bgColor: AppColors.infoLight,
        borderColor: AppColors.info.withValues(alpha: 0.3),
        valueColor: AppColors.info,
      ),
      _StatCard(
        label: 'Outstanding',
        value: CurrencyFormatter.format(outstanding),
        icon: Icons.receipt_long_outlined,
        iconColor: AppColors.warning,
        bgColor: AppColors.warningLight,
        borderColor: AppColors.warning.withValues(alpha: 0.3),
        valueColor: AppColors.warning,
        isAmount: true,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: isTablet
          ? Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: c,
                        ),
                      ))
                  .toList(),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 8),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final Color valueColor;
  final bool isAmount;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.valueColor,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isAmount ? 12 : 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
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

// Customer tile
class _CustomerTile extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

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
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                radius: 22,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    if (customer.phone != null)
                      Text(
                        customer.phone!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      customer.customerCode,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                  if (customer.currentBalance != 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(customer.currentBalance),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: customer.currentBalance > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Active/Inactive filter chip
class _ActiveChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ActiveChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
