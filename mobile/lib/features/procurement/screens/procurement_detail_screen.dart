import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/procurement_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/purchase_order_model.dart';

final _poDetailProvider =
    FutureProvider.family<PurchaseOrderModel, String>((ref, id) async {
  return ref.watch(procurementRepositoryProvider).getPurchaseOrder(id);
});

class ProcurementDetailScreen extends ConsumerWidget {
  final String orderId;
  const ProcurementDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poAsync = ref.watch(_poDetailProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Purchase Order'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: poAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.refresh(_poDetailProvider(orderId)),
        ),
        data: (po) => ContentWrapper(
          maxWidth: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PoHeader(po: po),
                InfoSection(
                  title: 'ORDER INFO',
                  children: [
                    InfoRow(
                      label: 'Order #',
                      value: po.orderNumber,
                      copyable: true,
                    ),
                    if (po.supplierName != null)
                      InfoRow(label: 'Supplier', value: po.supplierName!),
                    InfoRow(
                      label: 'Order Date',
                      value:
                          '${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year}',
                    ),
                    if (po.expectedDate != null)
                      InfoRow(
                        label: 'Expected',
                        value:
                            '${po.expectedDate!.day}/${po.expectedDate!.month}/${po.expectedDate!.year}',
                      ),
                    InfoRow(
                      label: 'Total',
                      value: CurrencyFormatter.format(po.totalAmount),
                      valueColor: AppColors.primary,
                      isLast: true,
                    ),
                  ],
                ),
                if (po.notes != null && po.notes!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOTES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          po.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (po.items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'LINE ITEMS (${po.items.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...po.items.map((item) => _LineItemTile(item: item)),
                  // Total summary — amber accented
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(po.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (po.isOrdered || po.isPartial || po.isReceived)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/procurement/receipts?poId=${po.id}',
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View Goods Receipts'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (po.isOrdered)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _CancelPoButton(po: po),
                  ),
                if (!po.isOrdered && !po.isPartial && !po.isReceived)
                  const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PoHeader extends StatelessWidget {
  final PurchaseOrderModel po;
  const _PoHeader({required this.po});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  po.orderNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: po.status),
            ],
          ),
          if (po.supplierName != null) ...[
            const SizedBox(height: 6),
            Text(
              po.supplierName!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineItemTile extends StatelessWidget {
  final PurchaseOrderItemModel item;
  const _LineItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final isFulfilled = item.quantityReceived >= item.quantityOrdered;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _Chip(
                      label: 'Ordered: ${item.quantityOrdered}',
                      color: AppColors.textSecondary,
                      bg: AppColors.surfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: 'Received: ${item.quantityReceived}',
                      color: isFulfilled
                          ? AppColors.success
                          : AppColors.warning,
                      bg: isFulfilled
                          ? AppColors.successLight
                          : AppColors.warningLight,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(item.lineTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '@ ${CurrencyFormatter.format(item.unitCost)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// Cancel PO button

class _CancelPoButton extends ConsumerStatefulWidget {
  final PurchaseOrderModel po;
  const _CancelPoButton({required this.po});

  @override
  ConsumerState<_CancelPoButton> createState() => _CancelPoButtonState();
}

class _CancelPoButtonState extends ConsumerState<_CancelPoButton> {
  bool _cancelling = false;

  Future<void> _confirmCancel() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Order',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will cancel the purchase order. This action cannot be undone.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final repo = ref.read(procurementRepositoryProvider);
      await repo.cancelPurchaseOrder(widget.po.id,
          reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Purchase order cancelled'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _cancelling ? null : _confirmCancel,
      icon: _cancelling
          ? const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
            )
          : const Icon(Icons.cancel_outlined),
      label: const Text('Cancel Order'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
