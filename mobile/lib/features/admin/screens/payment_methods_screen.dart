import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class _PaymentMethod {
  String type;
  String label;
  String accountNumber;
  String accountName;

  _PaymentMethod({
    required this.type,
    required this.label,
    required this.accountNumber,
    required this.accountName,
  });

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) {
    return _PaymentMethod(
      type: json['type'] as String? ?? 'OTHER',
      label: json['label'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'account_number': accountNumber,
        'account_name': accountName,
      };

  _PaymentMethod copyWith({
    String? type,
    String? label,
    String? accountNumber,
    String? accountName,
  }) =>
      _PaymentMethod(
        type: type ?? this.type,
        label: label ?? this.label,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName: accountName ?? this.accountName,
      );
}

const _kMethodTypes = [
  ('KPAY', 'KBZ Pay'),
  ('WAVEPAY', 'Wave Money'),
  ('AYA_PAY', 'AYA Pay'),
  ('CB_PAY', 'CB Pay'),
  ('BANK_TRANSFER', 'Bank Transfer'),
  ('OTHER', 'Other'),
];

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  List<_PaymentMethod> _methods = [];
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await apiClient.dio.get('/subscriptions/platform/payment-methods');
      final data = resp.data as Map<String, dynamic>;
      final rawList = data['payment_methods'] as List<dynamic>? ?? [];
      setState(() {
        _methods = rawList
            .map((e) => _PaymentMethod.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
        _dirty = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = AppException.fromDio(e).message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await apiClient.dio.put(
        '/subscriptions/admin/platform/payment-methods',
        data: {'payment_methods': _methods.map((m) => m.toJson()).toList()},
      );
      setState(() {
        _saving = false;
        _dirty = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment methods saved'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on DioException catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppException.fromDio(e).message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _addMethod() {
    setState(() {
      _methods.add(_PaymentMethod(
        type: 'KPAY',
        label: 'KBZ Pay',
        accountNumber: '',
        accountName: '',
      ));
      _dirty = true;
    });
  }

  void _removeMethod(int index) {
    setState(() {
      _methods.removeAt(index);
      _dirty = true;
    });
  }

  void _updateMethod(int index, _PaymentMethod updated) {
    setState(() {
      _methods[index] = updated;
      _dirty = true;
    });
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final tmp = _methods[index - 1];
      _methods[index - 1] = _methods[index];
      _methods[index] = tmp;
      _dirty = true;
    });
  }

  void _moveDown(int index) {
    if (index >= _methods.length - 1) return;
    setState(() {
      final tmp = _methods[index + 1];
      _methods[index + 1] = _methods[index];
      _methods[index] = tmp;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Subscription Payment Methods',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        children: [
                          // Info banner
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'These are the payment accounts shown to subscribers when paying for plans.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Header row
                          Row(
                            children: [
                              const Text(
                                'PAYMENT ACCOUNTS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _addMethod,
                                icon: const Icon(Icons.add, size: 16,
                                    color: AppColors.primary),
                                label: const Text('Add',
                                    style: TextStyle(color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_methods.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined,
                                      size: 36, color: AppColors.textDisabled),
                                  const SizedBox(height: 10),
                                  const Text('No payment accounts',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  const Text('Tap "Add" to add KBZ Pay, Wave Money, etc.',
                                      style: TextStyle(
                                          color: AppColors.textDisabled,
                                          fontSize: 12)),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _addMethod,
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Account'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...List.generate(
                              _methods.length,
                              (index) => _MethodCard(
                                method: _methods[index],
                                index: index,
                                total: _methods.length,
                                onRemove: () => _removeMethod(index),
                                onMoveUp: () => _moveUp(index),
                                onMoveDown: () => _moveDown(index),
                                onChanged: (m) => _updateMethod(index, m),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_dirty)
                      _SaveBar(saving: _saving, onSave: _save),
                  ],
                ),
    );
  }
}

class _MethodCard extends StatefulWidget {
  final _PaymentMethod method;
  final int index;
  final int total;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<_PaymentMethod> onChanged;

  const _MethodCard({
    required this.method,
    required this.index,
    required this.total,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard> {
  late TextEditingController _accountNumberCtrl;
  late TextEditingController _accountNameCtrl;
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _accountNumberCtrl =
        TextEditingController(text: widget.method.accountNumber);
    _accountNameCtrl =
        TextEditingController(text: widget.method.accountName);
    _labelCtrl = TextEditingController(text: widget.method.label);
  }

  @override
  void dispose() {
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(widget.method.copyWith(
      accountNumber: _accountNumberCtrl.text,
      accountName: _accountNameCtrl.text,
      label: _labelCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isOther = widget.method.type == 'OTHER';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: order controls + type + remove
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                // Up/down arrows
                Column(
                  children: [
                    InkWell(
                      onTap: widget.index == 0 ? null : widget.onMoveUp,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(Icons.keyboard_arrow_up,
                          size: 20,
                          color: widget.index == 0
                              ? AppColors.textDisabled
                              : AppColors.textSecondary),
                    ),
                    InkWell(
                      onTap: widget.index >= widget.total - 1
                          ? null
                          : widget.onMoveDown,
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 20,
                          color: widget.index >= widget.total - 1
                              ? AppColors.textDisabled
                              : AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // Type dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.method.type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
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
                    dropdownColor: AppColors.surfaceVariant,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    iconEnabledColor: AppColors.textSecondary,
                    items: _kMethodTypes
                        .map((t) => DropdownMenuItem<String>(
                              value: t.$1,
                              child: Text(t.$2),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final defaultLabel =
                          _kMethodTypes.firstWhere((t) => t.$1 == v).$2;
                      if (v != 'OTHER' && !isOther) {
                        _labelCtrl.text = defaultLabel;
                      }
                      widget.onChanged(widget.method.copyWith(
                        type: v,
                        label: v == 'OTHER' ? widget.method.label : defaultLabel,
                        accountNumber: _accountNumberCtrl.text,
                        accountName: _accountNameCtrl.text,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 4),
                // Remove button
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  style: IconButton.styleFrom(
                    hoverColor: AppColors.errorLight,
                  ),
                ),
              ],
            ),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                if (isOther) ...[
                  _MethodField(
                    label: 'Custom Label',
                    controller: _labelCtrl,
                    hint: 'e.g. City Bank, MPU Card…',
                    onChanged: (_) => _notify(),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _MethodField(
                        label: 'Account Number / Phone *',
                        controller: _accountNumberCtrl,
                        hint: '09-XXX-XXX-XXX',
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => _notify(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MethodField(
                        label: 'Account Name',
                        controller: _accountNameCtrl,
                        hint: 'Business Name',
                        onChanged: (_) => _notify(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _MethodField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppColors.textDisabled, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryFg,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryFg,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
