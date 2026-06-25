import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_model.dart';
import '../data/pos_repository.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final void Function(List<CheckoutPayment>) onConfirm;
  /// Whether a customer is attached to the current cart. Required for store
  /// credit payments — if false and store credit is selected the dialog will
  /// show an inline error instead of confirming.
  final bool hasCustomer;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirm,
    this.hasCustomer = false,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedMethod = PaymentMethod.cash;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final List<_SplitPaymentEntry> _splits = [];
  bool _isSplitMode = false;

  // Enhancement 2: bank name field
  String _bankName = '';

  // Inline validation error shown below the confirm button
  String? _inlineError;

  static const _presetBanks = ['KBZ', 'CB', 'AYA', 'MAB', 'AGD', 'Yoma'];

  // Enhancement 3: quick bill amounts
  static const _quickBills = [1000.0, 5000.0, 10000.0, 50000.0, 100000.0];

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  double get _enteredAmount =>
      double.tryParse(_amountController.text) ?? 0;

  double get _splitTotal =>
      _splits.fold(0, (sum, s) => sum + s.amount);

  double get _remainingForSplit =>
      widget.totalAmount - _splitTotal;

  double get _change =>
      _isSplitMode ? 0 : _enteredAmount - widget.totalAmount;

  String _quickBillLabel(double value) {
    if (value >= 1000) {
      return '${(value ~/ 1000)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _buildReference() {
    if (_selectedMethod == PaymentMethod.bankTransfer &&
        _bankName.isNotEmpty) {
      final ref = _refController.text.trim();
      return ref.isNotEmpty ? '$_bankName - $ref' : _bankName;
    }
    return _refController.text.isNotEmpty ? _refController.text : '';
  }

  void _confirm() {
    // L-03: guard against zero (or negative) total
    if (widget.totalAmount <= 0) {
      setState(() =>
          _inlineError = 'Cart total must be greater than zero.');
      return;
    }

    // H-05: store credit requires an attached customer
    if (!_isSplitMode &&
        _selectedMethod == PaymentMethod.storeCredit &&
        !widget.hasCustomer) {
      setState(() =>
          _inlineError =
              'Please add a customer to use store credit.');
      return;
    }
    if (_isSplitMode &&
        _splits.any((s) => s.method == PaymentMethod.storeCredit) &&
        !widget.hasCustomer) {
      setState(() =>
          _inlineError =
              'Please add a customer to use store credit.');
      return;
    }

    setState(() => _inlineError = null);

    if (_isSplitMode) {
      if (_splitTotal < widget.totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total payments must cover the full amount'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      widget.onConfirm(
          _splits.map((s) => s.toCheckoutPayment()).toList());
    } else {
      if (_enteredAmount < widget.totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Amount is less than the total'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final ref = _buildReference();
      widget.onConfirm([
        CheckoutPayment(
          paymentMethod: _selectedMethod,
          amount: widget.totalAmount,
          referenceNumber: ref.isNotEmpty ? ref : null,
        ),
      ]);
    }
  }

  void _addSplit() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;
    final ref = _buildReference();
    setState(() {
      _splits.add(_SplitPaymentEntry(
        method: _selectedMethod,
        amount: amount,
        reference: ref.isNotEmpty ? ref : null,
      ));
      _amountController.text =
          _remainingForSplit.toStringAsFixed(0);
      _refController.clear();
      _bankName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final splitProgress =
        (_splitTotal / widget.totalAmount).clamp(0.0, 1.0);
    final splitComplete = _splitTotal >= widget.totalAmount;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text('Payment',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                // Total amount display — amber
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(widget.totalAmount),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Split mode toggle
                Row(
                  children: [
                    const Text('Split Payment',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _isSplitMode,
                      onChanged: (v) => setState(() {
                        _isSplitMode = v;
                        _splits.clear();
                        _bankName = '';
                        _amountController.text =
                            widget.totalAmount.toStringAsFixed(0);
                      }),
                      activeThumbColor: AppColors.primaryFg,
                      activeTrackColor: AppColors.primary,
                    ),
                  ],
                ),

                // Enhancement 1: Progress bar in split mode
                if (_isSplitMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surfaceVariant,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: splitProgress,
                            minHeight: 8,
                            backgroundColor:
                                AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              splitComplete
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MMK ${_splitTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: splitComplete
                                    ? AppColors.success
                                    : AppColors.primary,
                              ),
                            ),
                            Text(
                              'MMK ${widget.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Split payments list
                if (_splits.isNotEmpty) ...[
                  ...List.generate(_splits.length, (i) {
                    final s = _splits[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              PaymentMethod.displayName(s.method),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(s.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _splits.removeAt(i)),
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.error),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: AppColors.divider),
                  if (_remainingForSplit > 0)
                    Text(
                      'Remaining: ${CurrencyFormatter.format(_remainingForSplit)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],

                // Payment method selection
                const Text('Payment Method',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                _PaymentMethodGrid(
                  selected: _selectedMethod,
                  onSelect: (m) => setState(() {
                    _selectedMethod = m;
                    _bankName = '';
                  }),
                ),
                const SizedBox(height: 16),

                // Enhancement 3: Quick bills (cash only, non-split)
                if (_selectedMethod == PaymentMethod.cash &&
                    !_isSplitMode) ...[
                  const Text('Quick Amount',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _quickBills.map((value) {
                      return GestureDetector(
                        onTap: () => setState(() {
                          _amountController.text =
                              value.toStringAsFixed(0);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.border),
                          ),
                          child: Text(
                            _quickBillLabel(value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Amount input — surfaceVariant fill
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: _isSplitMode
                        ? 'Amount for this payment'
                        : 'Amount Tendered',
                    labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13),
                    prefixText: 'MMK ',
                    prefixStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16),
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
                  onChanged: (_) => setState(() {}),
                ),

                // Reference field (for card/mobile payments)
                if (_selectedMethod != PaymentMethod.cash) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _refController,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Reference / Transaction ID',
                      labelStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13),
                      prefixIcon: Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                  ),
                ],

                // Enhancement 2: Bank name field (BANK_TRANSFER only)
                if (_selectedMethod == PaymentMethod.bankTransfer) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(_bankName),
                    initialValue: _bankName,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Bank Name',
                      labelStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13),
                      prefixIcon: Icon(
                          Icons.account_balance_outlined,
                          color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                    ),
                    onChanged: (v) => setState(() => _bankName = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _presetBanks.map((bank) {
                      final isSelected = _bankName == bank;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _bankName = bank),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.info
                                    .withValues(alpha: 0.12)
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.info
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            bank,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.info
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Change due — amber/green display
                if (!_isSplitMode &&
                    _selectedMethod == PaymentMethod.cash &&
                    _change > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change Due',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                              fontSize: 14,
                            )),
                        Text(
                          CurrencyFormatter.format(_change),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Add split payment button
                if (_isSplitMode && _remainingForSplit > 0)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _addSplit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment'),
                    ),
                  ),

                // Inline validation error (L-03, H-05)
                if (_inlineError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inlineError!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                if (!_isSplitMode || _splitTotal >= widget.totalAmount)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                      ),
                      icon: const Icon(Icons.check_circle_outline,
                          color: AppColors.primaryFg),
                      label: const Text('Confirm Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryFg,
                          )),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodGrid extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const _PaymentMethodGrid(
      {required this.selected, required this.onSelect});

  static const _methods = [
    (PaymentMethod.cash, Icons.payments_outlined, AppColors.cashColor),
    (PaymentMethod.card, Icons.credit_card_outlined, AppColors.cardColor),
    (PaymentMethod.kpay, Icons.phone_android_outlined, AppColors.mobilePayColor),
    (PaymentMethod.wavepay, Icons.waves_outlined, AppColors.mobilePayColor),
    (PaymentMethod.ayaPay, Icons.account_balance_wallet_outlined, AppColors.mobilePayColor),
    (PaymentMethod.cbPay, Icons.account_balance_wallet_outlined, AppColors.mobilePayColor),
    (PaymentMethod.bankTransfer, Icons.account_balance_outlined, AppColors.info),
    (PaymentMethod.storeCredit, Icons.loyalty_outlined, AppColors.secondary),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _methods.map((m) {
        final isSelected = selected == m.$1;
        return GestureDetector(
          onTap: () => onSelect(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // surfaceVariant base, amber-tinted when selected
              color: isSelected
                  ? m.$3.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? m.$3 : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.$2,
                    size: 16,
                    color: isSelected
                        ? m.$3
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  PaymentMethod.displayName(m.$1),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isSelected
                        ? m.$3
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SplitPaymentEntry {
  final String method;
  final double amount;
  final String? reference;

  const _SplitPaymentEntry(
      {required this.method, required this.amount, this.reference});

  CheckoutPayment toCheckoutPayment() => CheckoutPayment(
        paymentMethod: method,
        amount: amount,
        referenceNumber: reference,
      );
}
