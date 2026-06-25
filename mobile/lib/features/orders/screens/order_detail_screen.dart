import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../data/orders_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../models/order_model.dart';

// Provider

final _orderDetailProvider =
    FutureProvider.family<OrderModel, String>((ref, id) async {
  return ref.watch(ordersRepositoryProvider).getOrder(id);
});

// Screen

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _isVoiding = false;

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  Future<void> _confirmVoid(BuildContext context, OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Void Order',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to void order ${order.orderNumber}? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Void Order',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isVoiding = true);
    try {
      await ref
          .read(ordersRepositoryProvider)
          .voidOrder(order.id, reason: 'Voided from mobile app');
      ref.invalidate(_orderDetailProvider(widget.orderId));
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Order voided successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to void order: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVoiding = false);
    }
  }

  void _showRefundSheet(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RefundSheet(
        order: order,
        onSuccess: () {
          ref.invalidate(_orderDetailProvider(widget.orderId));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Refund processed successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(_orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: orderAsync.whenOrNull(
              data: (o) => Text(
                'Order #${o.orderNumber}',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
              ),
            ) ??
            const Text('Order Details',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        actions: [
          orderAsync.whenOrNull(
                data: (o) => IconButton(
                  icon: const Icon(Icons.print_outlined, color: AppColors.primary),
                  tooltip: 'Print Receipt',
                  onPressed: () => context.push('/receipt/${o.id}'),
                ),
              ) ??
              const SizedBox(),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_orderDetailProvider(widget.orderId)),
        ),
        data: (order) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status section
              _SectionHeader(label: 'STATUS'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Order Status',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        _StatusBadge(
                            status: order.orderStatus, type: _BadgeType.order),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Payment Status',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        _StatusBadge(
                            status: order.paymentStatus,
                            type: _BadgeType.payment),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Date',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (order.cashierSessionId != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Session ID',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              order.cashierSessionId!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Customer section
              if (order.customerName != null) ...[
                _SectionHeader(label: 'CUSTOMER'),
                InfoSection(
                  children: [
                    InfoRow(
                        label: 'Name', value: order.customerName!),
                    if (order.customerId != null)
                      InfoRow(
                          label: 'ID',
                          value: order.customerId!,
                          isLast: true),
                  ],
                ),
              ],

              // Items table
              _SectionHeader(label: 'ITEMS'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppColors.divider)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text('PRODUCT',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8)),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text('QTY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8)),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text('UNIT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8)),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text('TOTAL',
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
                    // Table rows
                    ...order.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isLast = i == order.items.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom:
                                      BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                item.displayName,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${item.quantityOrdered}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text(
                                CurrencyFormatter.formatCompact(
                                    item.unitPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                            SizedBox(
                              width: 88,
                              child: Text(
                                CurrencyFormatter.formatCompact(
                                    item.lineTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
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

              // Totals section
              _SectionHeader(label: 'TOTALS'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TotalRow(
                        label: 'Subtotal',
                        value: CurrencyFormatter.format(order.grossTotal)),
                    const SizedBox(height: 8),
                    _TotalRow(
                        label: 'Tax',
                        value: CurrencyFormatter.format(order.taxTotal)),
                    const SizedBox(height: 8),
                    _TotalRow(
                        label: 'Discount',
                        value:
                            '- ${CurrencyFormatter.format(order.discountTotal)}',
                        valueColor: order.discountTotal > 0
                            ? AppColors.success
                            : null),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: AppColors.divider, height: 1),
                    ),
                    _TotalRow(
                      label: 'Total',
                      value: CurrencyFormatter.format(order.netTotal),
                      labelStyle: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                      valueStyle: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

              // Payments section
              if (order.payments.isNotEmpty) ...[
                _SectionHeader(label: 'PAYMENTS'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: order.payments.asMap().entries.map((entry) {
                      final i = entry.key;
                      final payment = entry.value;
                      final isLast = i == order.payments.length - 1;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: AppColors.divider)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    PaymentMethod.displayName(
                                        payment.paymentMethod),
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  if (payment.referenceNumber != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Ref: ${payment.referenceNumber}',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(payment.amount),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                _StatusBadge(
                                    status: payment.paymentStatus,
                                    type: _BadgeType.payment),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Refund button
              if (order.orderStatus == 'COMPLETED' ||
                  order.orderStatus == 'PARTIALLY_REFUNDED') ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.replay_outlined, size: 18),
                      label: const Text(
                        'Process Refund',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _showRefundSheet(context, order),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Void button
              if (!order.isVoided) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isVoiding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: AppColors.error, strokeWidth: 2),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        _isVoiding ? 'Voiding...' : 'Void Order',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: _isVoiding
                          ? null
                          : () => _confirmVoid(context, order),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
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

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _TotalRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: labelStyle ??
              const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: valueStyle ??
              TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

enum _BadgeType { order, payment }

class _StatusBadge extends StatelessWidget {
  final String status;
  final _BadgeType type;

  const _StatusBadge({required this.status, required this.type});

  (Color, Color) get _colors {
    if (type == _BadgeType.order) {
      switch (status.toUpperCase()) {
        case 'COMPLETED':
          return (AppColors.successLight, AppColors.success);
        case 'VOIDED':
          return (AppColors.errorLight, AppColors.error);
        case 'PENDING':
          return (AppColors.warningLight, AppColors.warning);
        default:
          return (AppColors.surfaceVariant, AppColors.textSecondary);
      }
    } else {
      switch (status.toUpperCase()) {
        case 'PAID':
        case 'COMPLETED':
          return (AppColors.successLight, AppColors.success);
        case 'UNPAID':
        case 'FAILED':
          return (AppColors.errorLight, AppColors.error);
        case 'PARTIAL':
          return (AppColors.warningLight, AppColors.warning);
        case 'REFUNDED':
          return (AppColors.infoLight, AppColors.info);
        default:
          return (AppColors.surfaceVariant, AppColors.textSecondary);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// Refund Sheet

class _SelectedItem {
  final OrderItemModel item;
  int qty;

  _SelectedItem({required this.item, required this.qty});

  double get amount {
    final quantityOrdered = item.quantityOrdered;
    final unitPrice = item.unitPrice;
    final unitTotal = quantityOrdered > 0
        ? (item.lineTotal / quantityOrdered)
        : unitPrice;
    return double.parse((unitTotal * qty).toStringAsFixed(2));
  }
}

class _RefundSheet extends ConsumerStatefulWidget {
  final OrderModel order;
  final VoidCallback onSuccess;

  const _RefundSheet({required this.order, required this.onSuccess});

  @override
  ConsumerState<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends ConsumerState<_RefundSheet> {
  String _refundMethod = 'CASH';
  final Map<String, _SelectedItem> _selected = {};
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggleItem(OrderItemModel item) {
    setState(() {
      if (_selected.containsKey(item.id)) {
        _selected.remove(item.id);
      } else {
        _selected[item.id] = _SelectedItem(item: item, qty: item.quantityOrdered);
      }
    });
  }

  void _setQty(OrderItemModel item, int qty) {
    if (item.quantityOrdered < 1) return;
    final clamped = qty.clamp(1, item.quantityOrdered);
    setState(() {
      _selected[item.id] = _SelectedItem(item: item, qty: clamped);
    });
  }

  double get _totalRefund =>
      _selected.values.fold(0.0, (s, x) => s + x.amount);

  bool get _canSubmit =>
      _selected.isNotEmpty && _reasonCtrl.text.trim().length >= 3;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      final items = _selected.values.map((s) => {
        'order_item_id': s.item.id,
        'quantity': s.qty.toString(),
        'amount': s.amount.toString(),
      }).toList();
      await ref.read(ordersRepositoryProvider).processRefund(
        widget.order.id,
        items: items,
        refundMethod: _refundMethod,
        reason: _reasonCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppException.fromDio(e).message),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final items = widget.order.items;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.replay_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Process Refund',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                // Order number badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.order.orderNumber,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Refund type toggle
                  const Text(
                    'REFUND TYPE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _refundMethod = 'CASH'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: _refundMethod == 'CASH'
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(9)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '💵  Cash Refund',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _refundMethod == 'CASH'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Money returned · stock restored',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _refundMethod == 'CASH'
                                          ? Colors.white70
                                          : AppColors.textDisabled,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 48,
                            color: AppColors.divider),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _refundMethod = 'REPLACEMENT'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: _refundMethod == 'REPLACEMENT'
                                    ? const Color(0xFF7C3AED)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(9)),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '🔄  Replacement',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _refundMethod == 'REPLACEMENT'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'New item given · stock reduced',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _refundMethod == 'REPLACEMENT'
                                          ? Colors.white70
                                          : AppColors.textDisabled,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'SELECT ITEMS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Items list
                  ...items.map((item) {
                    final sel = _selected[item.id];
                    final isSelected = sel != null;
                    return GestureDetector(
                      onTap: () => _toggleItem(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  width: 1.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 12,
                                      color: AppColors.primaryFg)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            // Product info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayName,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyFormatter.formatCompact(item.unitPrice)} × ${item.quantityOrdered}  =  ${CurrencyFormatter.formatCompact(item.lineTotal)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Qty stepper (only when selected)
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {},
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    _QtyButton(
                                      icon: Icons.remove,
                                      onTap: () => _setQty(
                                          item, sel.qty - 1),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Text(
                                        '${sel.qty}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    _QtyButton(
                                      icon: Icons.add,
                                      onTap: () => _setQty(
                                          item, sel.qty + 1),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 72,
                                      child: Text(
                                        CurrencyFormatter.format(
                                            sel.amount),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Reason field
                  TextField(
                    controller: _reasonCtrl,
                    onChanged: (_) => setState(() {}),
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Reason (required, min 3 chars)',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Additional notes (optional)',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border:
                  Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                if (_selected.isNotEmpty) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_selected.length} item${_selected.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11),
                      ),
                      Text(
                        CurrencyFormatter.format(_totalRefund),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canSubmit && !_submitting ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryFg),
                          )
                        : const Text(
                            'Process Refund',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
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

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
