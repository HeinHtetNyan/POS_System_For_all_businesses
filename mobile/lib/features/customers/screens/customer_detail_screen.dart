import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customers_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import 'customer_form_screen.dart';
import 'customer_ledger_screen.dart';
import 'customer_payments_screen.dart';
import 'customer_sale_form_screen.dart';
import 'customer_statement_screen.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../models/customer_model.dart';
import '../../../models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:intl/intl.dart';

final _customerDetailProvider =
    FutureProvider.family<CustomerModel, String>((ref, id) async {
  final repo = ref.watch(customersRepositoryProvider);
  return repo.getCustomer(id);
});

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(_customerDetailProvider(customerId));
    final user = ref.watch(currentUserProvider);
    final canEdit =
        user?.role != UserRole.cashier && user?.role != UserRole.inventoryStaff;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          customerAsync.whenOrNull(
                data: (c) => IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'Ledger',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomerLedgerScreen(
                        customerId: c.id, customerName: c.name),
                  )),
                ),
              ) ??
              const SizedBox(),
          if (canEdit)
            customerAsync.whenOrNull(
                  data: (c) => IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CustomerFormScreen(customer: c),
                        fullscreenDialog: true,
                      ),
                    ),
                  ),
                ) ??
                const SizedBox(),
        ],
      ),
      body: customerAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.refresh(_customerDetailProvider(customerId)),
        ),
        data: (customer) => ContentWrapper(
          maxWidth: 720,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _CustomerHeader(customer: customer),
                _CustomerStatCards(customer: customer),
                InfoSection(
                  title: 'CONTACT',
                  children: [
                    if (customer.phone != null)
                      InfoRow(label: 'Phone', value: customer.phone!),
                    if (customer.email != null)
                      InfoRow(label: 'Email', value: customer.email!),
                    InfoRow(label: 'Code', value: customer.customerCode),
                    InfoRow(
                      label: 'Status',
                      value: customer.isActive ? 'Active' : 'Inactive',
                      valueColor: customer.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ],
                ),
                if (customer.notes != null && customer.notes!.isNotEmpty)
                  InfoSection(
                    title: 'INTERNAL NOTES',
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Text(
                          customer.notes!,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                if (customer.creditLimit > 0)
                  InfoSection(
                    title: 'CREDIT',
                    children: [
                      InfoRow(
                          label: 'Credit Limit',
                          value:
                              CurrencyFormatter.format(customer.creditLimit)),
                      InfoRow(
                          label: 'Balance',
                          value:
                              CurrencyFormatter.format(customer.currentBalance),
                          valueColor: customer.currentBalance > 0
                              ? AppColors.error
                              : AppColors.success),
                      InfoRow(
                          label: 'Available',
                          value: CurrencyFormatter.format(
                              customer.availableCredit),
                          valueColor: AppColors.success),
                    ],
                  ),
                // Actions
                const _SectionLabel(label: 'ACTIONS'),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance_outlined,
                          size: 18, color: AppColors.secondary),
                    ),
                    title: const Text('Statement',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    subtitle: const Text('View transaction history & balance',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerStatementScreen(customer: customer),
                      ),
                    ),
                  ),
                ),
                if (customer.currentBalance > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: AppColors.success,
                        ),
                      ),
                      title: const Text('Record Payment',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text(
                          'Apply a payment against outstanding balance',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.success),
                      onTap: () async {
                        final saved = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                CustomerPaymentsScreen(customer: customer),
                            fullscreenDialog: true,
                          ),
                        );
                        if (saved == true) {
                          ref.invalidate(_customerDetailProvider(customerId));
                        }
                      },
                    ),
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_shopping_cart_outlined,
                            size: 18, color: AppColors.primary),
                      ),
                      title: const Text('New Order',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: const Text('Create a sale for this customer',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.primary),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerSaleFormScreen(customer: customer),
                          fullscreenDialog: true,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Stat Cards

class _CustomerStatCards extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerStatCards({required this.customer});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('MMM d, yyyy').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = Responsive.isTablet(context);
    final outstanding = customer.currentBalance;
    final outstandingColor =
        outstanding > 0 ? AppColors.error : AppColors.textSecondary;

    final cards = [
      _CustomerStatCard(
        label: 'Total Orders',
        value: customer.totalOrders.toString(),
        icon: Icons.receipt_outlined,
        iconColor: AppColors.info,
      ),
      _CustomerStatCard(
        label: 'Total Spent',
        value: CurrencyFormatter.format(customer.totalSpent),
        icon: Icons.payments_outlined,
        iconColor: AppColors.success,
      ),
      _CustomerStatCard(
        label: 'Outstanding',
        value: CurrencyFormatter.format(outstanding),
        icon: Icons.account_balance_wallet_outlined,
        iconColor: outstandingColor,
        valueColor: outstandingColor,
      ),
      _CustomerStatCard(
        label: 'Member Since',
        value: _formatDate(customer.createdAt),
        icon: Icons.calendar_today_outlined,
        iconColor: AppColors.secondary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: isTablet
          ? Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: cards.indexOf(c) < cards.length - 1 ? 8 : 0,
                          ),
                          child: c,
                        ),
                      ))
                  .toList(),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: cards[0],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: cards[1],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: cards[2],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: cards[3],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CustomerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;

  const _CustomerStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.0),
      ),
    );
  }
}

// Header

class _CustomerHeader extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasBalance = customer.currentBalance > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Avatar row
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.surfaceVariant,
                child: Text(
                  customer.name.isNotEmpty
                      ? customer.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    if (customer.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer.phone!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                    if (customer.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        customer.email!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: customer.isActive
                      ? AppColors.successLight
                      : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  customer.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color:
                        customer.isActive ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Balance badge (only if outstanding)
          if (hasBalance) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Outstanding Balance',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(customer.currentBalance),
                    style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
