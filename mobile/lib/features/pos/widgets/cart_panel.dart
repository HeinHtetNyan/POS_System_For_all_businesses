import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pos_provider.dart';
import '../../orders/data/orders_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../models/cart_model.dart';
import '../../../models/customer_model.dart';
import '../../../models/order_model.dart';

class CartPanel extends ConsumerWidget {
  final String branchId;
  final String sessionId;
  final VoidCallback onCheckout;
  final VoidCallback onClear;

  const CartPanel({
    super.key,
    required this.branchId,
    required this.sessionId,
    required this.onCheckout,
    required this.onClear,
  });

  void _showRefundSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RefundSheet(),
    );
  }

  void _showCustomerSearchSheet(
      BuildContext context, WidgetRef ref,
      ({String branchId, String sessionId}) cartParams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomerSearchSheet(
        onSelected: (customer) {
          ref.read(posCartProvider(cartParams).notifier).setCustomer(customer);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartParams = (branchId: branchId, sessionId: sessionId);
    final cartState = ref.watch(posCartProvider(cartParams));

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (cartState.itemCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${cartState.itemCount}',
                          style: const TextStyle(
                            color: AppColors.primaryFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Refund button
                    IconButton(
                      icon: const Icon(Icons.undo_outlined,
                          color: AppColors.textSecondary, size: 20),
                      tooltip: 'Process Refund',
                      onPressed: () => _showRefundSheet(context),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    if (!cartState.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        tooltip: 'Clear cart',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                    color: AppColors.divider),
                              ),
                              title: const Text('Clear Cart?',
                                  style: TextStyle(
                                      color: AppColors.textPrimary)),
                              content: const Text(
                                'This will remove all items from the cart.',
                                style: TextStyle(
                                    color: AppColors.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onClear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),

                // Customer selector row
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 8),
                  child: cartState.customer == null
                      ? GestureDetector(
                          onTap: () => _showCustomerSearchSheet(
                              context, ref, cartParams),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: AppColors.divider),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add_outlined,
                                    size: 15,
                                    color: AppColors.textSecondary),
                                SizedBox(width: 6),
                                Text(
                                  'Add Customer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar circle
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  cartState.customer!.name.isNotEmpty
                                      ? cartState.customer!.name
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  cartState.customer!.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (cartState.customer!.phone != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  cartState.customer!.phone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => ref
                                    .read(posCartProvider(cartParams)
                                        .notifier)
                                    .setCustomer(null),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Cart items
          Expanded(
            child: cartState.isEmpty
                ? _EmptyCart(onRefund: () => _showRefundSheet(context))
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 56,
                        color: AppColors.divider),
                    itemBuilder: (ctx, idx) {
                      final item = cartState.items[idx];
                      return _CartItemRow(
                        item: item,
                        onIncrement: () => ref
                            .read(posCartProvider(cartParams).notifier)
                            .incrementItem(item.key),
                        onDecrement: () => ref
                            .read(posCartProvider(cartParams).notifier)
                            .decrementItem(item.key),
                        onRemove: () => ref
                            .read(posCartProvider(cartParams).notifier)
                            .removeItem(item.key),
                      );
                    },
                  ),
          ),

          // Summary + checkout
          if (!cartState.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value:
                        CurrencyFormatter.format(cartState.subtotal),
                  ),
                  if (cartState.taxTotal > 0)
                    _SummaryRow(
                      label: 'Tax',
                      value:
                          CurrencyFormatter.format(cartState.taxTotal),
                    ),
                  if (cartState.lineDiscountTotal > 0)
                    _SummaryRow(
                      label: 'Item Discount',
                      value:
                          '- ${CurrencyFormatter.format(cartState.lineDiscountTotal)}',
                      valueColor: AppColors.success,
                    ),
                  // Order-level discount row + button
                  _OrderDiscountRow(
                    cartParams: cartParams,
                    cartState: cartState,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.divider),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      Text(
                        CurrencyFormatter.format(cartState.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          cartState.isCheckingOut ? null : onCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.5),
                      ),
                      icon: cartState.isCheckingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryFg,
                              ),
                            )
                          : const Icon(Icons.payment_rounded,
                              color: AppColors.primaryFg),
                      label: Text(
                        cartState.isCheckingOut
                            ? 'Processing...'
                            : 'Charge  ${CurrencyFormatter.format(cartState.total)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryFg,
                        ),
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

// Customer Search Bottom Sheet

class _CustomerSearchSheet extends StatefulWidget {
  final ValueChanged<CustomerModel> onSelected;

  const _CustomerSearchSheet({required this.onSelected});

  @override
  State<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends State<_CustomerSearchSheet> {
  final _searchCtrl = TextEditingController();
  final _repo = CustomersRepository();
  List<CustomerModel> _results = [];
  bool _isLoading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Load initial list
    _doSearch('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _doSearch(value.trim());
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repo.listCustomers(
        search: query.isEmpty ? null : query,
        isActive: true,
        pageSize: 30,
      );
      if (mounted) {
        setState(() {
          _results = result.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title + search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Customer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: AppColors.textPrimary),
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone...',
                      hintStyle: const TextStyle(
                          color: AppColors.textDisabled, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_outlined,
                          size: 18, color: AppColors.textSecondary),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16,
                                  color: AppColors.textSecondary),
                              onPressed: () {
                                _searchCtrl.clear();
                                _doSearch('');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
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
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: EmptyView(
                                icon: Icons.person_search_outlined,
                                title: 'No customers found',
                                subtitle: 'Try a different name or phone',
                              ),
                            )
                          : ListView.separated(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  indent: 56,
                                  color: AppColors.divider),
                              itemBuilder: (_, idx) {
                                final customer = _results[idx];
                                return _CustomerResultTile(
                                  customer: customer,
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onSelected(customer);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerResultTile extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;

  const _CustomerResultTile({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name.substring(0, 1).toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customer.phone != null || customer.customerCode.isNotEmpty)
                    Text(
                      [
                        if (customer.phone != null) customer.phone!,
                        if (customer.customerCode.isNotEmpty)
                          '#${customer.customerCode}',
                      ].join('  ·  '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

// Refund sheet

class _RefundSheet extends ConsumerStatefulWidget {
  const _RefundSheet();

  @override
  ConsumerState<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends ConsumerState<_RefundSheet> {
  final _orderNumCtrl = TextEditingController();
  OrderModel? _foundOrder;
  bool _isSearching = false;
  String? _searchError;
  final Set<String> _selectedItemIds = {};
  String _refundMethod = 'CASH';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _orderNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _orderNumCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundOrder = null;
      _selectedItemIds.clear();
    });
    try {
      final result = await ref
          .read(ordersRepositoryProvider)
          .listOrders(search: q, pageSize: 5);
      final match = result.items.firstWhere(
        (o) => o.orderNumber.toLowerCase() == q.toLowerCase(),
        orElse: () =>
            result.items.isNotEmpty ? result.items.first : throw Exception('Order not found'),
      );
      if (mounted) {
        setState(() {
          _foundOrder = match;
          _selectedItemIds.addAll(match.items.map((i) => i.id));
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Order not found';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final order = _foundOrder;
    if (order == null || _selectedItemIds.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final items = order.items
          .where((i) => _selectedItemIds.contains(i.id))
          .map((i) => {
                'order_item_id': i.id,
                'quantity': i.quantityOrdered,
              })
          .toList();

      await ref
          .read(ordersRepositoryProvider)
          .processRefund(
            order.id,
            items: items,
            refundMethod: _refundMethod,
            reason: 'Refund from POS',
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund processed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        color: AppColors.surface,
        child: Column(
          children: [
            // Handle + title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Process Refund',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  // Order number search
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _orderNumCtrl,
                          style: const TextStyle(
                              color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Enter order number...',
                            hintStyle: const TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 13),
                            prefixIcon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                                color: AppColors.textSecondary),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 12),
                            filled: true,
                            fillColor: AppColors.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.divider),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: AppColors.primary),
                            ),
                            errorText: _searchError,
                            errorStyle: const TextStyle(
                                color: AppColors.error, fontSize: 11),
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSearching ? null : _search,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryFg,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryFg),
                              )
                            : const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            // Order details + item selection
            Expanded(
              child: _foundOrder == null
                  ? Center(
                      child: EmptyView(
                        icon: Icons.manage_search_outlined,
                        title: 'Search for an order',
                        subtitle: 'Enter the order number above',
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Order summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _foundOrder!.orderNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                    if (_foundOrder!.customerName !=
                                        null)
                                      Text(
                                        _foundOrder!.customerName!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(
                                    _foundOrder!.netTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Select items to refund:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        ..._foundOrder!.items.map((item) {
                          final checked =
                              _selectedItemIds.contains(item.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedItemIds.add(item.id);
                                } else {
                                  _selectedItemIds.remove(item.id);
                                }
                              });
                            },
                            title: Text(
                              item.displayName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary),
                            ),
                            subtitle: Text(
                              '${item.quantityOrdered}× ${CurrencyFormatter.format(item.unitPrice)}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            activeColor: AppColors.primary,
                            checkColor: AppColors.primaryFg,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          );
                        }),
                        const SizedBox(height: 12),
                        const Text('Refund method:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                        RadioGroup<String>(
                          groupValue: _refundMethod,
                          onChanged: (v) =>
                              setState(() => _refundMethod = v ?? _refundMethod),
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                value: 'CASH',
                                title: const Text('Cash',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                fillColor:
                                    WidgetStateProperty.resolveWith(
                                  (s) => s.contains(
                                          WidgetState.selected)
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                              RadioListTile<String>(
                                value: 'REPLACEMENT',
                                title: const Text('Replacement',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                fillColor:
                                    WidgetStateProperty.resolveWith(
                                  (s) => s.contains(
                                          WidgetState.selected)
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting ||
                                    _selectedItemIds.isEmpty)
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.primaryFg,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primaryFg),
                                  )
                                : const Text('Process Refund',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Order-level discount row

class _OrderDiscountRow extends ConsumerStatefulWidget {
  final ({String branchId, String sessionId}) cartParams;
  final PosCartState cartState;

  const _OrderDiscountRow(
      {required this.cartParams, required this.cartState});

  @override
  ConsumerState<_OrderDiscountRow> createState() =>
      _OrderDiscountRowState();
}

class _OrderDiscountRowState extends ConsumerState<_OrderDiscountRow> {
  bool _editing = false;
  String _type = 'PERCENT';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _apply() {
    final v = double.tryParse(_ctrl.text.trim()) ?? 0;
    ref
        .read(posCartProvider(widget.cartParams).notifier)
        .setOrderDiscount(_type, v);
    setState(() => _editing = false);
  }

  void _clear() {
    _ctrl.clear();
    ref
        .read(posCartProvider(widget.cartParams).notifier)
        .clearOrderDiscount();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = widget.cartState.orderDiscountType != null &&
        widget.cartState.orderDiscountValue > 0;

    if (!_editing && !hasDiscount) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GestureDetector(
          onTap: () => setState(() => _editing = true),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Add Order Discount',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.primary)),
            ],
          ),
        ),
      );
    }

    if (hasDiscount && !_editing) {
      final label = widget.cartState.orderDiscountType == 'PERCENT'
          ? '${widget.cartState.orderDiscountValue.toStringAsFixed(0)}% off'
          : CurrencyFormatter.format(widget.cartState.orderDiscountValue);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Order Discount',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    _type = widget.cartState.orderDiscountType!;
                    _ctrl.text = widget.cartState.orderDiscountValue
                        .toStringAsFixed(
                            widget.cartState.orderDiscountType == 'PERCENT'
                                ? 0
                                : 2);
                    setState(() => _editing = true);
                  },
                  child: const Icon(Icons.edit_outlined,
                      size: 13, color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _clear,
                  child: const Icon(Icons.close,
                      size: 13, color: AppColors.error),
                ),
              ],
            ),
            Text(
              '($label)  - ${CurrencyFormatter.format(widget.cartState.orderDiscountAmount)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success),
            ),
          ],
        ),
      );
    }

    // Editing state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            _TypeBtn(
              label: '%',
              selected: _type == 'PERCENT',
              onTap: () => setState(() => _type = 'PERCENT'),
            ),
            const SizedBox(width: 6),
            _TypeBtn(
              label: 'Amt',
              selected: _type == 'AMOUNT',
              onTap: () => setState(() => _type = 'AMOUNT'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText:
                        _type == 'PERCENT' ? 'e.g. 10' : 'e.g. 5000',
                    hintStyle: const TextStyle(
                        color: AppColors.textDisabled, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _apply,
              child: Container(
                height: 36,
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check,
                    size: 18, color: AppColors.primaryFg),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _clear,
              child: Container(
                height: 36,
                width: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeBtn(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// Cart item row

class _CartItemRow extends StatelessWidget {
  final LocalCartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  CurrencyFormatter.format(item.unitPrice),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(item.lineSubtotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SmallBtn(
                icon: Icons.add,
                color: AppColors.primary,
                onTap: onIncrement,
              ),
              const SizedBox(height: 2),
              _SmallBtn(
                icon: item.quantity <= 1
                    ? Icons.delete_outline
                    : Icons.remove,
                color: item.quantity <= 1
                    ? AppColors.error
                    : AppColors.textSecondary,
                onTap: item.quantity <= 1 ? onRemove : onDecrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onRefund;

  const _EmptyCart({required this.onRefund});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 48, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          const Text(
            'Cart is empty',
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a product to add it',
            style: TextStyle(
                fontSize: 12, color: AppColors.textDisabled),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRefund,
            icon: const Icon(Icons.undo_outlined,
                size: 16, color: AppColors.primary),
            label: const Text('Process a refund',
                style: TextStyle(
                    color: AppColors.primary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
