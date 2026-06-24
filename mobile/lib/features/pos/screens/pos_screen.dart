import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pos_provider.dart';
import '../widgets/product_grid.dart';
import '../widgets/cart_panel.dart';
import '../widgets/payment_dialog.dart';
import '../../cashier_session/providers/session_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_model.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  bool _showCartSheet = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final session = ref.watch(sessionProvider).session;
    final isOnline = ref.watch(isOnlineProvider);

    if (user == null || session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Gate: POS checkout requires tablet (≥600dp). Small phones are not supported.
    if (MediaQuery.of(context).size.width < 600) {
      return Scaffold(
        appBar: AppBar(title: const Text('Point of Sale')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tablet_mac_outlined,
                    size: 80, color: AppColors.textSecondary),
                const SizedBox(height: 24),
                const Text('Tablet Required',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                  'The POS checkout is not available on small screens.\nPlease use a tablet or larger device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final branchId = user.primaryBranchId ?? session.branchId;
    final cartParams = (branchId: branchId, sessionId: session.id);
    final cartState = ref.watch(posCartProvider(cartParams));

    // Listen for completed order
    ref.listen<PosCartState>(posCartProvider(cartParams),
        (prev, next) {
      if (next.lastCompletedOrder != null &&
          (prev?.lastCompletedOrder == null)) {
        _showOrderComplete(context, next.lastCompletedOrder!, cartParams);
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(posCartProvider(cartParams).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          // Offline indicator
          if (!isOnline)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 14,
                      color: AppColors.warning),
                  SizedBox(width: 4),
                  Text('Offline',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.warning)),
                ],
              ),
            ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'session',
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Close Session'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'orders',
                child: ListTile(
                  leading: Icon(Icons.receipt_long_outlined),
                  title: Text('Order History'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  dense: true,
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'logout') {
                ref.read(authProvider.notifier).logout();
              } else if (v == 'session') {
                context.push('/session/close');
              } else if (v == 'orders') {
                context.push('/orders');
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          // Tablet layout: side by side
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                // Product grid (left, 60%)
                Expanded(
                  flex: 60,
                  child: ProductGrid(
                    branchId: branchId,
                    sessionId: session.id,
                    branchIdForCart: branchId,
                  ),
                ),
                const VerticalDivider(width: 1),
                // Cart (right, 40%)
                SizedBox(
                  width: constraints.maxWidth * 0.38,
                  child: CartPanel(
                    branchId: branchId,
                    sessionId: session.id,
                    onCheckout: () => _showPaymentDialog(
                        context, cartState.total, cartParams),
                    onClear: () => ref
                        .read(posCartProvider(cartParams).notifier)
                        .clearCart(),
                  ),
                ),
              ],
            );
          }

          // Phone layout: full product grid + bottom cart button
          return Stack(
            children: [
              ProductGrid(
                branchId: branchId,
                sessionId: session.id,
                branchIdForCart: branchId,
                onItemAdded: () {
                  if (!_showCartSheet) {
                    setState(() => _showCartSheet = true);
                  }
                },
              ),
              if (!cartState.isEmpty)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCartBottomSheet(
                        context, branchId, session.id, cartParams),
                    icon: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Icon(Icons.shopping_cart_outlined),
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${cartState.itemCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    label: Text(
                        'View Cart · ${CurrencyFormatter.format(cartState.total)}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showCartBottomSheet(
    BuildContext context,
    String branchId,
    String sessionId,
    ({String branchId, String sessionId}) cartParams,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Consumer(builder: (context, ref, _) {
          final cartState = ref.watch(posCartProvider(cartParams));
          return CartPanel(
            branchId: branchId,
            sessionId: sessionId,
            onCheckout: () {
              Navigator.pop(ctx);
              _showPaymentDialog(
                  context, cartState.total, cartParams);
            },
            onClear: () {
              Navigator.pop(ctx);
              ref
                  .read(posCartProvider(cartParams).notifier)
                  .clearCart();
            },
          );
        }),
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    double total,
    ({String branchId, String sessionId}) cartParams,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialog(
        totalAmount: total,
        onConfirm: (payments) {
          Navigator.pop(context);
          ref
              .read(posCartProvider(cartParams).notifier)
              .checkout(payments);
        },
      ),
    );
  }

  void _showOrderComplete(
    BuildContext context,
    OrderModel order,
    ({String branchId, String sessionId}) cartParams,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Sale Complete!',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Order #${order.orderNumber}',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(order.netTotal),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(posCartProvider(cartParams).notifier)
                          .clearLastOrder();
                      context.push('/receipt/${order.id}');
                    },
                    icon: const Icon(Icons.receipt_outlined,
                        size: 18),
                    label: const Text('Receipt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref
                          .read(posCartProvider(cartParams).notifier)
                          .clearLastOrder();
                    },
                    icon: const Icon(Icons.add_shopping_cart,
                        size: 18),
                    label: const Text('New Sale'),
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
