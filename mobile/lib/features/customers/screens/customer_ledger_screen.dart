import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customers_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';

final _ledgerProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, customerId) async {
  return ref.watch(customersRepositoryProvider).getLedger(customerId);
});

class CustomerLedgerScreen extends ConsumerWidget {
  final String customerId;
  final String customerName;

  const CustomerLedgerScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  void _showRecordPaymentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecordPaymentSheet(
        customerId: customerId,
        onSuccess: () => ref.invalidate(_ledgerProvider(customerId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(_ledgerProvider(customerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ledger',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(
              customerName,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPaymentSheet(context, ref),
        label: const Text('Record Payment',
            style: TextStyle(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.payment_outlined),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryFg,
      ),
      body: ContentWrapper(
        maxWidth: 720,
        child: ledgerAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.refresh(_ledgerProvider(customerId)),
          ),
          data: (entries) => entries.isEmpty
              ? const EmptyView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No ledger entries',
                  subtitle: 'Transactions will appear here',
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _LedgerEntryTile(entry: entries[i]),
                ),
        ),
      ),
    );
  }
}

// Record Payment bottom sheet

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final String customerId;
  final VoidCallback onSuccess;

  const _RecordPaymentSheet({
    required this.customerId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amtStr = _amountCtrl.text.trim();
    if (amtStr.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    final amount = double.tryParse(amtStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final note = _noteCtrl.text.trim();
      final refText = _refCtrl.text.trim();
      await ref.read(customersRepositoryProvider).recordPayment(
        widget.customerId,
        {
          'amount': amount,
          if (note.isNotEmpty) 'note': note,
          if (refText.isNotEmpty) 'reference': refText,
        },
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Record Payment',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDec('Amount *', Icons.attach_money_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration:
                _inputDec('Note (optional)', Icons.notes_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration:
                _inputDec('Reference (optional)', Icons.tag_outlined),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryFg),
                    )
                  : const Text('Submit',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}

// Ledger entry tile

class _LedgerEntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = entry['entry_type'] as String? ?? 'TRANSACTION';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final balance = (entry['balance_after'] as num?)?.toDouble();
    final description = entry['description'] as String? ??
        entry['reference'] as String? ??
        type;
    final rawDate = entry['created_at'] as String? ??
        entry['entry_date'] as String?;
    DateTime? date;
    if (rawDate != null) {
      try {
        date = DateTime.parse(rawDate);
      } catch (_) {}
    }

    final isCredit = type.contains('PAYMENT') ||
        type.contains('CREDIT') ||
        amount > 0;

    final Color amountColor =
        isCredit ? AppColors.success : AppColors.error;
    final Color iconBg =
        isCredit ? AppColors.successLight : AppColors.errorLight;
    final IconData icon =
        isCredit ? Icons.arrow_downward : Icons.arrow_upward;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: amountColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${date.day.toString().padLeft(2, '0')}/'
                      '${date.month.toString().padLeft(2, '0')}/'
                      '${date.year}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'} ${CurrencyFormatter.format(amount.abs())}',
                  style: TextStyle(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (balance != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Bal: ${CurrencyFormatter.formatCompact(balance)}',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
