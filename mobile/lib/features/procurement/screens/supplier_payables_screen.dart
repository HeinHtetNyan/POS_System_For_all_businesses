import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/status_badge.dart';

class SupplierPayable {
  final String id;
  final String supplierName;
  final String purchaseOrderRef;
  final double totalAmount;
  final double paidAmount;
  final double balance;
  final DateTime? dueDate;
  final String status;

  const SupplierPayable({
    required this.id,
    required this.supplierName,
    required this.purchaseOrderRef,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
    this.dueDate,
    required this.status,
  });

  factory SupplierPayable.fromJson(Map<String, dynamic> json) {
    return SupplierPayable(
      id: json['id'] as String,
      supplierName: json['supplier_name'] as String? ?? '',
      purchaseOrderRef: json['purchase_order_ref'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

final payablesProvider =
    FutureProvider.autoDispose.family<List<SupplierPayable>, String?>(
  (ref, supplierId) async {
    final params = <String, dynamic>{
      if (supplierId != null) 'supplier_id': supplierId,
    };
    final response = await apiClient.dio.get(
      ApiEndpoints.payables,
      queryParameters: params.isNotEmpty ? params : null,
    );
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    return rawItems
        .map((e) => SupplierPayable.fromJson(e as Map<String, dynamic>))
        .toList();
  },
);

class SupplierPayablesScreen extends ConsumerStatefulWidget {
  final String? supplierId;

  const SupplierPayablesScreen({super.key, this.supplierId});

  @override
  ConsumerState<SupplierPayablesScreen> createState() =>
      _SupplierPayablesScreenState();
}

class _SupplierPayablesScreenState
    extends ConsumerState<SupplierPayablesScreen> {
  String? _activeFilter;

  List<SupplierPayable> _applyFilter(List<SupplierPayable> items) {
    if (_activeFilter == null) return items;
    return items.where((p) => p.status == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final payablesAsync = ref.watch(payablesProvider(widget.supplierId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Supplier Payables',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: ContentWrapper(
        child: payablesAsync.when(
        loading: () => const ShimmerList(itemCount: 7, itemHeight: 140),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(payablesProvider(widget.supplierId)),
        ),
        data: (items) {
          final filtered = _applyFilter(items);
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async =>
                ref.invalidate(payablesProvider(widget.supplierId)),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SummaryBanner(items: items),
                ),
                SliverToBoxAdapter(
                  child: _FilterChips(
                    active: _activeFilter,
                    onSelect: (f) => setState(() => _activeFilter = f),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No payables found',
                      subtitle:
                          'Supplier payables will appear here when purchase orders are created',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _PayableCard(
                          payable: filtered[i],
                          onPaymentRecorded: () => ref
                              .invalidate(payablesProvider(widget.supplierId)),
                        ),
                        childCount: filtered.length,
                      ),
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

class _SummaryBanner extends StatelessWidget {
  final List<SupplierPayable> items;

  const _SummaryBanner({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalOutstanding =
        items.fold<double>(0, (sum, p) => sum + p.balance);
    final overdueItems =
        items.where((p) => p.status == 'overdue').toList();
    final totalOverdue =
        overdueItems.fold<double>(0, (sum, p) => sum + p.balance);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BannerStat(
              label: 'Total Outstanding',
              amount: totalOutstanding,
              color: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 44,
            color: AppColors.divider,
          ),
          Expanded(
            child: _BannerStat(
              label: 'Total Overdue',
              amount: totalOverdue,
              color: AppColors.error,
              count: overdueItems.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final int? count;

  const _BannerStat({
    required this.label,
    required this.amount,
    required this.color,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String? active;
  final void Function(String?) onSelect;

  const _FilterChips({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const filters = [null, 'pending', 'partial', 'overdue'];
    const labels = ['All', 'Pending', 'Partial', 'Overdue'];

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final selected = active == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PayableCard extends StatelessWidget {
  final SupplierPayable payable;
  final VoidCallback onPaymentRecorded;

  const _PayableCard({
    required this.payable,
    required this.onPaymentRecorded,
  });

  bool get _isOverdue => payable.status == 'overdue';

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String get _dueDateLabel {
    if (payable.dueDate == null) return 'No due date';
    return 'Due ${_fmtDate(payable.dueDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isOverdue
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payable.supplierName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                StatusBadge(status: payable.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.receipt_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  payable.purchaseOrderRef,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 13,
                  color: _isOverdue ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  _dueDateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _isOverdue ? AppColors.error : AppColors.textSecondary,
                    fontWeight:
                        _isOverdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Balance Due',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(payable.balance),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _isOverdue
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'of ${CurrencyFormatter.format(payable.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (payable.status != 'paid')
                  GestureDetector(
                    onTap: () => _showRecordPaymentSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Record Payment',
                        style: TextStyle(
                          color: AppColors.primaryFg,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecordPaymentSheet(
        payable: payable,
        onSaved: onPaymentRecorded,
      ),
    );
  }
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final SupplierPayable payable;
  final VoidCallback onSaved;

  const _RecordPaymentSheet({
    required this.payable,
    required this.onSaved,
  });

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  String _method = 'cash';
  bool _saving = false;
  String? _error;

  static const _methods = [
    ('cash', 'Cash'),
    ('bank_transfer', 'Bank Transfer'),
    ('cheque', 'Cheque'),
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.payable.balance.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await apiClient.dio.post(
        '${ApiEndpoints.payables}/${widget.payable.id}/payments',
        data: {
          'amount': double.parse(_amountCtrl.text.trim()),
          'payment_method': _method,
          'notes': _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      setState(() {
        _error = e is AppException ? e.message : 'Failed to record payment';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Payment',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.payable.supplierName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: AppColors.divider),
            const SizedBox(height: 20),
            const Text(
              'Amount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: _inputDecoration('Enter amount'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Amount is required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                if (parsed > widget.payable.balance) {
                  return 'Amount exceeds balance of ${CurrencyFormatter.format(widget.payable.balance)}';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _method,
              dropdownColor: AppColors.surfaceVariant,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              iconEnabledColor: AppColors.textSecondary,
              decoration: _inputDecoration(null),
              items: _methods
                  .map((m) => DropdownMenuItem(
                        value: m.$1,
                        child: Text(m.$2),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _method = v);
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Notes (optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: _inputDecoration('Add a note...'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _saving
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primaryFg,
                          ),
                        )
                      : const Text(
                          'Save Payment',
                          style: TextStyle(
                            color: AppColors.primaryFg,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      errorStyle: const TextStyle(
        color: AppColors.error,
        fontSize: 11,
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load payables',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: AppColors.primaryFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
