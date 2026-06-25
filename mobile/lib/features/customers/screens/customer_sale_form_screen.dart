import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../features/cashier_session/providers/session_provider.dart';
import '../../../features/products/data/products_repository.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';

const _kPaymentMethods = [
  {'value': 'CASH', 'label': 'Cash'},
  {'value': 'CARD', 'label': 'Card'},
  {'value': 'BANK_TRANSFER', 'label': 'Bank Transfer'},
  {'value': 'KBZPAY', 'label': 'KBZPay'},
  {'value': 'WAVEPAY', 'label': 'WavePay'},
];

class CustomerSaleFormScreen extends ConsumerStatefulWidget {
  final CustomerModel customer;
  const CustomerSaleFormScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerSaleFormScreen> createState() =>
      _CustomerSaleFormScreenState();
}

class _CustomerSaleFormScreenState
    extends ConsumerState<CustomerSaleFormScreen> {
  final _searchCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _search = '';
  List<ProductModel> _products = [];
  bool _productsLoading = false;
  final Map<String, _CartEntry> _cart = {};
  String _paymentMethod = 'CASH';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts([String search = '']) async {
    setState(() => _productsLoading = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final result = await repo.listProducts(
          search: search.isEmpty ? null : search, pageSize: 200, isActive: true);
      if (mounted) setState(() => _products = result.items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  double get _subtotal => _cart.values
      .fold(0, (sum, e) => sum + e.product.sellingPrice * e.quantity);

  double get _paid {
    final v = double.tryParse(_paidCtrl.text) ?? 0;
    return v.clamp(0, _subtotal);
  }

  double get _remaining => _subtotal - _paid;

  void _addToCart(ProductModel p) {
    setState(() {
      if (_cart.containsKey(p.id)) {
        _cart[p.id] = _CartEntry(p, _cart[p.id]!.quantity + 1);
      } else {
        _cart[p.id] = _CartEntry(p, 1);
      }
    });
  }

  void _removeFromCart(String id) {
    setState(() => _cart.remove(id));
  }

  void _updateQty(String id, int qty) {
    if (qty <= 0) {
      _removeFromCart(id);
    } else {
      setState(() => _cart[id] = _CartEntry(_cart[id]!.product, qty));
    }
  }

  Future<void> _submit() async {
    final session = ref.read(sessionProvider).session;
    if (session == null) {
      _showSnack('No active cashier session. Please open a session first.',
          isError: true);
      return;
    }
    if (_cart.isEmpty) {
      _showSnack('Add at least one product', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final items = _cart.values.map((e) => {
            'product_id': e.product.id,
            'quantity': e.quantity.toString(),
            'unit_price': e.product.sellingPrice.toStringAsFixed(4),
            'discount_amount': '0',
            'tax_rate': (e.product.taxRate / 100).toStringAsFixed(4),
          }).toList();

      final payments = <Map<String, dynamic>>[];
      if (_paid > 0) {
        payments.add({
          'payment_method': _paymentMethod,
          'amount': _paid.toStringAsFixed(4),
        });
      }

      await apiClient.dio.post('/sales/checkout', data: {
        'cashier_session_id': session.id,
        'items': items,
        'payments': payments,
        'customer_id': widget.customer.id,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to create order', isError: true);
        setState(() => _submitting = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).session;
    final newBalance =
        widget.customer.currentBalance + _remaining;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('New Order — ${widget.customer.name}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
            overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: session == null
          ? _NoSessionView()
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _productPanel()),
                      Container(width: 1, color: AppColors.divider),
                      SizedBox(width: 360, child: _orderPanel(newBalance)),
                    ],
                  );
                }
                return Column(
                  children: [
                    Expanded(child: _productPanel()),
                    Container(height: 1, color: AppColors.divider),
                    SizedBox(height: 340, child: _orderPanel(newBalance)),
                  ],
                );
              },
            ),
    );
  }

  Widget _productPanel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search products…',
              hintStyle: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 13),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 18),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 16, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                        _fetchProducts();
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() => _search = v);
              _fetchProducts(v);
            },
          ),
        ),
        Expanded(
          child: _productsLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : _products.isEmpty
                  ? const Center(
                      child: Text('No products found',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _products.length,
                      itemBuilder: (_, i) {
                        final p = _products[i];
                        final inCart = _cart[p.id]?.quantity ?? 0;
                        return _ProductTile(
                          product: p,
                          cartQty: inCart,
                          onAdd: () => _addToCart(p),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _orderPanel(double newBalance) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cart items
                if (_cart.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('Select products',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  )
                else ...[
                  ..._cart.values.map((e) => _CartItemRow(
                        entry: e,
                        onUpdateQty: (qty) => _updateQty(e.product.id, qty),
                        onRemove: () => _removeFromCart(e.product.id),
                      )),
                  Divider(color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      Text(CurrencyFormatter.format(_subtotal),
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Payment
                _FieldLabel('Paid Now'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _paidCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: _inputDeco(hint: '0 = on account'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SmallBtn(
                      label: 'Full',
                      onTap: _subtotal > 0
                          ? () {
                              _paidCtrl.text =
                                  _subtotal.toStringAsFixed(0);
                              setState(() {});
                            }
                          : null,
                    ),
                    const SizedBox(width: 6),
                    _SmallBtn(
                      label: 'None',
                      onTap: _subtotal > 0
                          ? () {
                              _paidCtrl.clear();
                              setState(() {});
                            }
                          : null,
                    ),
                  ],
                ),

                if (_paid > 0) ...[
                  const SizedBox(height: 10),
                  _FieldLabel('Payment Method'),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMethod,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    decoration: _inputDeco(),
                    onChanged: (v) {
                      if (v != null) setState(() => _paymentMethod = v);
                    },
                    items: _kPaymentMethods
                        .map((m) => DropdownMenuItem(
                              value: m['value'],
                              child: Text(m['label']!),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 10),
                _FieldLabel('Notes (optional)'),
                const SizedBox(height: 4),
                TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  decoration: _inputDeco(hint: 'Order notes…'),
                ),

                if (_cart.isNotEmpty) ...[
                  Divider(color: AppColors.divider, height: 20),
                  _SummaryRow('Paying now',
                      CurrencyFormatter.format(_paid),
                      valueColor: AppColors.success),
                  const SizedBox(height: 4),
                  _SummaryRow(
                    'Balance after',
                    CurrencyFormatter.format(newBalance),
                    valueColor: newBalance > 0
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    bold: true,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Submit button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _cart.isEmpty ? AppColors.surfaceVariant : AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed:
                  _cart.isEmpty || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryFg))
                  : Text(
                      _cart.isEmpty
                          ? 'Add items to continue'
                          : _paid >= _subtotal && _subtotal > 0
                              ? 'Create Order — Paid in Full'
                              : _paid > 0
                                  ? 'Create Order — Partially Paid'
                                  : 'Create Order — On Account',
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textDisabled, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );
}

// Sub-widgets

class _CartEntry {
  final ProductModel product;
  final int quantity;
  const _CartEntry(this.product, this.quantity);
}

class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final int cartQty;
  final VoidCallback onAdd;

  const _ProductTile(
      {required this.product, required this.cartQty, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: cartQty > 0
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  if (product.sku != null)
                    Text(product.sku!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.format(product.sellingPrice),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(width: 8),
            if (cartQty > 0)
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: Text('$cartQty',
                    style: const TextStyle(
                        color: AppColors.primaryFg,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              )
            else
              const Icon(Icons.add_circle_outline,
                  size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final _CartEntry entry;
  final void Function(int qty) onUpdateQty;
  final VoidCallback onRemove;

  const _CartItemRow(
      {required this.entry,
      required this.onUpdateQty,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.product.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text(
                    '${CurrencyFormatter.format(entry.product.sellingPrice)} ea',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBtn(
                  icon: Icons.remove,
                  onTap: () => onUpdateQty(entry.quantity - 1)),
              SizedBox(
                width: 28,
                child: Text('${entry.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
              ),
              _QtyBtn(
                  icon: Icons.add,
                  onTap: () => onUpdateQty(entry.quantity + 1)),
            ],
          ),
          const SizedBox(width: 8),
          Text(
              CurrencyFormatter.format(
                  entry.product.sellingPrice * entry.quantity),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace')),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SmallBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: onTap == null
                    ? AppColors.textDisabled
                    : AppColors.textSecondary,
                fontSize: 12)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _SummaryRow(this.label, this.value,
      {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: bold ? 14 : 12)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: bold ? 14 : 12,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'monospace')),
      ],
    );
  }
}

class _NoSessionView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_outlined,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No active cashier session',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a cashier session before creating orders.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryFg),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
