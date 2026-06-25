import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customers_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../models/customer_model.dart';

// Provider

final _customerLedgerProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, id) async {
  return ref.watch(customersRepositoryProvider).getLedger(id);
});

// Screen

class CustomerStatementScreen extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const CustomerStatementScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerStatementScreen> createState() =>
      _CustomerStatementScreenState();
}

class _CustomerStatementScreenState
    extends ConsumerState<CustomerStatementScreen> {
  DateTimeRange? _dateRange;

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = raw is DateTime ? raw : DateTime.parse(raw.toString());
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  List<Map<String, dynamic>> _applyDateFilter(
      List<Map<String, dynamic>> entries) {
    if (_dateRange == null) return entries;
    return entries.where((e) {
      final raw = e['date'] ?? e['created_at'];
      if (raw == null) return true;
      try {
        final dt = raw is DateTime ? raw : DateTime.parse(raw.toString());
        final start = _dateRange!.start;
        final end = _dateRange!.end.add(const Duration(days: 1));
        return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            dt.isBefore(end);
      } catch (_) {
        return true;
      }
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateRange,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.primaryFg,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync =
        ref.watch(_customerLedgerProvider(widget.customer.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Statement — ${widget.customer.name}',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range_outlined,
              color:
                  _dateRange != null ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: 'Filter by date',
            onPressed: _pickDateRange,
          ),
          if (_dateRange != null)
            IconButton(
              icon: const Icon(Icons.clear, color: AppColors.textSecondary),
              tooltip: 'Clear date filter',
              onPressed: () => setState(() => _dateRange = null),
            ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.textSecondary),
            tooltip: 'Print',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printing not available in mobile'),
                  backgroundColor: AppColors.surfaceVariant,
                ),
              );
            },
          ),
        ],
      ),
      body: ContentWrapper(
        maxWidth: 720,
        child: ledgerAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_customerLedgerProvider(widget.customer.id)),
        ),
        data: (allEntries) {
          final entries = _applyDateFilter(allEntries);

          // Compute summary from filtered entries
          double totalPurchases = 0;
          String? lastPaymentDate;

          for (final e in entries) {
            final amount = _toDouble(e['amount']);
            final entryType =
                (e['entry_type'] as String? ?? '').toUpperCase();
            final isPayment = entryType.contains('PAYMENT') ||
                entryType.contains('CREDIT');
            if (!isPayment && amount > 0) {
              totalPurchases += amount;
            }
            if (isPayment) {
              final raw = e['date'] ?? e['created_at'];
              lastPaymentDate = _formatDate(raw);
            }
          }

          final outstandingBalance =
              widget.customer.currentBalance;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date filter banner
                if (_dateRange != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Filtered: ${_formatDate(_dateRange!.start)} — ${_formatDate(_dateRange!.end)}',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Summary card
                const _SectionHeader(label: 'SUMMARY'),
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Total Purchases',
                        value: CurrencyFormatter.format(totalPurchases),
                        icon: Icons.shopping_bag_outlined,
                        iconColor: AppColors.info,
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Outstanding Balance',
                        value: CurrencyFormatter.format(outstandingBalance),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: outstandingBalance > 0
                            ? AppColors.warning
                            : AppColors.success,
                        valueColor: outstandingBalance > 0
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Last Payment',
                        value: lastPaymentDate ?? 'No payments',
                        icon: Icons.payments_outlined,
                        iconColor: AppColors.secondary,
                      ),
                    ],
                  ),
                ),

                // Statement table
                const _SectionHeader(label: 'TRANSACTIONS'),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions',
                      subtitle: 'No ledger entries found',
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom:
                                    BorderSide(color: AppColors.divider)),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 76,
                                child: Text('DATE',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8)),
                              ),
                              Expanded(
                                child: Text('DESCRIPTION',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8)),
                              ),
                              SizedBox(
                                width: 68,
                                child: Text('DEBIT',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8)),
                              ),
                              SizedBox(
                                width: 68,
                                child: Text('CREDIT',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8)),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text('BALANCE',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8)),
                              ),
                            ],
                          ),
                        ),
                        // Data rows
                        ...entries.asMap().entries.map((entry) {
                          final i = entry.key;
                          final row = entry.value;
                          final isLast = i == entries.length - 1;
                          final amount = _toDouble(row['amount']);
                          final entryType =
                              (row['entry_type'] as String? ?? '').toUpperCase();
                          final isPayment = entryType.contains('PAYMENT') ||
                              entryType.contains('CREDIT');
                          // Positive amount = debit (charge); PAYMENT type = credit
                          final debit = (!isPayment && amount > 0) ? amount : 0.0;
                          final credit = isPayment ? amount.abs() : 0.0;
                          final balance =
                              _toDouble(row['balance_after'] ?? row['balance']);
                          final desc =
                              (row['description'] as String?)?.trim() ??
                                  (row['entry_type'] as String?)?.trim() ??
                                  '-';
                          final dateRaw =
                              row['date'] ?? row['created_at'];

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: i.isOdd
                                  ? AppColors.surfaceVariant
                                      .withValues(alpha: 0.3)
                                  : Colors.transparent,
                              border: isLast
                                  ? null
                                  : const Border(
                                      bottom: BorderSide(
                                          color: AppColors.divider,
                                          width: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 76,
                                  child: Text(
                                    _formatDate(dateRaw),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    desc,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    debit > 0
                                        ? CurrencyFormatter
                                            .formatCompact(debit)
                                        : '-',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 11),
                                  ),
                                ),
                                SizedBox(
                                  width: 68,
                                  child: Text(
                                    credit > 0
                                        ? CurrencyFormatter
                                            .formatCompact(credit)
                                        : '-',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        color: AppColors.success,
                                        fontSize: 11),
                                  ),
                                ),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    CurrencyFormatter.formatCompact(
                                        balance),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        color: balance > 0
                                            ? AppColors.warning
                                            : AppColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
        ),
      ),
    );
  }
}

// Helpers

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
