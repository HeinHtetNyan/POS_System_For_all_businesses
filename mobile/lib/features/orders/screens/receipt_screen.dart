import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/orders_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/hardware/printer_service.dart';
import '../../../models/order_model.dart';

final _orderDetailProvider =
    FutureProvider.family<OrderModel, String>((ref, id) async {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.getOrder(id);
});

class ReceiptScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ReceiptScreen({super.key, required this.orderId});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool? _autoPrintResult; // null = not tried, true = sent, false = no printer

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(_orderDetailProvider(widget.orderId));

    // Auto-print once when order loads and any printer transport is connected
    ref.listen<AsyncValue<OrderModel>>(
        _orderDetailProvider(widget.orderId), (prev, next) {
      if (_autoPrintResult != null) return; // already attempted
      if (next is AsyncData<OrderModel>) {
        if (printerService.isAnyConnected) {
          printerService
              .printReceipt(next.value, openDrawer: false)
              .then((ok) {
            if (mounted) setState(() => _autoPrintResult = ok);
          });
        } else {
          // No printer — mark as skipped (false) so banner shows correct state
          setState(() => _autoPrintResult = false);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Receipt'),
        actions: [
          orderAsync.whenOrNull(
            data: (order) => IconButton(
              icon: const Icon(Icons.print_outlined,
                  color: AppColors.primary),
              tooltip:
                  _autoPrintResult == true ? 'Reprint' : 'Print Receipt',
              onPressed: () => _printReceipt(context, order),
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
          onRetry: () =>
              ref.refresh(_orderDetailProvider(widget.orderId)),
        ),
        data: (order) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Auto-print status banner
              if (_autoPrintResult == true)
                _StatusBanner(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  bgColor: AppColors.successLight,
                  borderColor: AppColors.success.withValues(alpha: 0.3),
                  message: 'Receipt sent to printer automatically',
                )
              else if (_autoPrintResult == false &&
                  printerService.isAnyConnected)
                _StatusBanner(
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.warning,
                  bgColor: AppColors.warningLight,
                  borderColor:
                      AppColors.warning.withValues(alpha: 0.3),
                  message:
                      'Auto-print failed — tap the print icon to retry',
                ),
              _ReceiptHeader(order: order),
              const SizedBox(height: 12),
              _ItemsCard(order: order),
              const SizedBox(height: 8),
              _TotalsCard(order: order),
              const SizedBox(height: 8),
              _PaymentsCard(order: order),
              const SizedBox(height: 24),
              _PrintButton(
                order: order,
                label: _autoPrintResult == true
                    ? 'Reprint Receipt'
                    : 'Print Receipt',
                onPrint: () => _printReceipt(context, order),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(
      BuildContext context, OrderModel order) async {
    final ok =
        await printerService.printReceipt(order, openDrawer: false);
    if (!context.mounted) return;
    if (mounted) setState(() => _autoPrintResult = ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Sent to printer'
            : 'No printer connected. Connect in settings.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String message;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  final OrderModel order;
  const _ReceiptHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.receipt_long,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              order.orderNumber,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusBadge(status: order.orderStatus),
                const SizedBox(width: 8),
                StatusBadge(status: order.paymentStatus),
              ],
            ),
            const Divider(height: 24, color: AppColors.divider),
            InfoRow(
              label: 'Date',
              value: _fmt(order.createdAt),
            ),
            if (order.customerName != null)
              InfoRow(
                  label: 'Customer', value: order.customerName!),
            if (order.cashierSessionId != null)
              InfoRow(
                  label: 'Session',
                  value: order.cashierSessionId!.length >= 8
                      ? order.cashierSessionId!.substring(0, 8)
                      : order.cashierSessionId!),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _ItemsCard extends StatelessWidget {
  final OrderModel order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ITEMS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              )),
                          Text(
                            '${item.quantityOrdered} × ${CurrencyFormatter.format(item.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.lineTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
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

class _TotalsCard extends StatelessWidget {
  final OrderModel order;
  const _TotalsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InfoRow(
              label: 'Subtotal',
              value: CurrencyFormatter.format(order.grossTotal),
            ),
            if (order.taxTotal > 0)
              InfoRow(
                label: 'Tax',
                value: CurrencyFormatter.format(order.taxTotal),
                valueColor: AppColors.textPrimary,
              ),
            if (order.discountTotal > 0)
              InfoRow(
                label: 'Discount',
                value:
                    '- ${CurrencyFormatter.format(order.discountTotal)}',
                valueColor: AppColors.success,
              ),
            const Divider(color: AppColors.divider),
            Row(
              children: [
                const Expanded(
                  child: Text('Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      )),
                ),
                Text(
                  CurrencyFormatter.format(order.netTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  final OrderModel order;
  const _PaymentsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.payments.isEmpty) return const SizedBox();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PAYMENTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...order.payments.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              PaymentMethod.displayName(
                                  p.paymentMethod),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              )),
                          if (p.referenceNumber != null)
                            Text('Ref: ${p.referenceNumber}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(p.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
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

class _PrintButton extends StatelessWidget {
  final OrderModel order;
  final String label;
  final VoidCallback onPrint;
  const _PrintButton(
      {required this.order, required this.label, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPrint,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryFg,
        ),
        icon: const Icon(Icons.print_outlined,
            color: AppColors.primaryFg),
        label: Text(label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryFg,
            )),
      ),
    );
  }
}
