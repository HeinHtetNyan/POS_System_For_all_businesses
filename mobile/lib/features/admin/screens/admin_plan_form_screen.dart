import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class AdminPlanFormScreen extends ConsumerStatefulWidget {
  final String? planId;
  const AdminPlanFormScreen({super.key, this.planId});

  @override
  ConsumerState<AdminPlanFormScreen> createState() =>
      _AdminPlanFormScreenState();
}

class _AdminPlanFormScreenState extends ConsumerState<AdminPlanFormScreen> {
  bool get isEditing => widget.planId != null;

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _trialDaysCtrl = TextEditingController();

  String _billingCycle = 'MONTHLY';

  final Map<String, bool> _toggleFeatures = {
    'pos': true,
    'inventory': true,
    'analytics': false,
    'advanced_reports': false,
    'procurement': false,
    'sync': true,
    'notifications': true,
  };

  final Map<String, String> _limitValues = {
    'products': '',
    'branches': '',
    'users': '',
    'customers': '',
    'devices': '',
  };

  bool _isLoading = false;
  String? _loadError;

  // Feature metadata

  static const Map<String, List<String>> _toggleMeta = {
    'pos': ['POS / Checkout', 'Access the point-of-sale checkout screen'],
    'inventory': ['Inventory', 'Stock tracking and adjustments'],
    'analytics': ['Analytics', 'Sales and financial analytics'],
    'advanced_reports': ['Advanced Reports', 'Detailed reports and exports'],
    'procurement': ['Procurement', 'Suppliers, purchase orders, payables'],
    'sync': ['Offline Sync', 'Work offline and sync later'],
    'notifications': ['Notifications', 'In-app alerts and reminders'],
  };

  static const Map<String, List<String>> _limitMeta = {
    'products': ['Max Products', 'e.g. 100'],
    'branches': ['Max Branches', 'e.g. 1'],
    'users': ['Max Staff', 'e.g. 5'],
    'customers': ['Max Customers', 'e.g. 500'],
    'devices': ['Max Devices', 'e.g. 3'],
  };

  // Lifecycle

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      Future.microtask(_loadPlan);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _trialDaysCtrl.dispose();
    super.dispose();
  }

  // Data loading

  Future<void> _loadPlan() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final res = await apiClient.get(
        '/subscriptions/plans/${widget.planId}',
      );
      final data = res.data as Map<String, dynamic>;

      _nameCtrl.text = (data['name'] as String?) ?? '';
      _descCtrl.text = (data['description'] as String?) ?? '';
      _priceCtrl.text = (data['monthly_price'] ?? data['price'] ?? '').toString();
      _trialDaysCtrl.text = (data['trial_days'] ?? 0).toString();
      _billingCycle = (data['billing_cycle'] as String?) ?? 'MONTHLY';

      final entitlements = data['entitlements'] as List<dynamic>? ?? [];
      for (final e in entitlements) {
        final code = e['feature_code'] as String? ?? '';
        final enabled = e['enabled'] as bool? ?? false;
        final limitVal = e['limit_value'];

        if (_toggleFeatures.containsKey(code)) {
          _toggleFeatures[code] = enabled;
        } else if (_limitValues.containsKey(code)) {
          _limitValues[code] = limitVal != null ? limitVal.toString() : '';
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e is AppException ? e.message : e.toString();
      });
    }
  }

  // Submit

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final entitlements = [
      ..._toggleFeatures.entries.map((e) => {
            'feature_code': e.key,
            'enabled': e.value,
            'limit_value': null,
          }),
      ..._limitValues.entries.map((e) => {
            'feature_code': e.key,
            'enabled': true,
            'limit_value': e.value.trim().isEmpty
                ? null
                : int.tryParse(e.value.trim()),
          }),
    ];

    final payload = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'monthly_price': double.parse(_priceCtrl.text.trim()),
      'billing_cycle': _billingCycle,
      'trial_days': int.tryParse(_trialDaysCtrl.text.trim()) ?? 0,
      'entitlements': entitlements,
    };

    setState(() => _isLoading = true);
    try {
      if (isEditing) {
        await apiClient.patch(
          '/subscriptions/plans/${widget.planId}',
          data: payload,
        );
      } else {
        await apiClient.post(
          '/subscriptions/plans',
          data: payload,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AppException ? e.message : 'Something went wrong.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.errorLight,
        ),
      );
    }
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Plan' : 'New Plan',
          style: const TextStyle(
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
      body: _isLoading && isEditing && _nameCtrl.text.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _loadError != null
              ? _ErrorRetry(
                  message: _loadError!,
                  onRetry: _loadPlan,
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Plan Details'),
                  const SizedBox(height: 12),
                  _buildDetailsSection(),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Features'),
                  const SizedBox(height: 4),
                  _buildFeaturesSection(),
                  const SizedBox(height: 28),
                  _SectionHeader(title: 'Limits'),
                  const SizedBox(height: 4),
                  _buildLimitsSection(),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  // Details section

  Widget _buildDetailsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _FormField(
            controller: _nameCtrl,
            label: 'Plan Name',
            hint: 'e.g. Starter, Pro, Enterprise',
            isFirst: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          _Divider(),
          _FormField(
            controller: _priceCtrl,
            label: 'Price',
            hint: '0',
            prefix: 'MMK ',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Price is required';
              if (double.tryParse(v.trim()) == null) {
                return 'Enter a valid number';
              }
              return null;
            },
          ),
          _Divider(),
          _buildBillingCycleField(),
          _Divider(),
          _FormField(
            controller: _descCtrl,
            label: 'Description',
            hint: 'Optional plan description',
            maxLines: 3,
          ),
          _Divider(),
          _FormField(
            controller: _trialDaysCtrl,
            label: 'Trial Days',
            hint: '0 = no trial',
            keyboardType: TextInputType.number,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Billing Cycle',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _CycleChip(
                label: 'Monthly',
                selected: _billingCycle == 'MONTHLY',
                onTap: () => setState(() => _billingCycle = 'MONTHLY'),
              ),
              const SizedBox(width: 10),
              _CycleChip(
                label: 'Yearly',
                selected: _billingCycle == 'YEARLY',
                onTap: () => setState(() => _billingCycle = 'YEARLY'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Features section

  Widget _buildFeaturesSection() {
    final entries = _toggleMeta.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final code = entries[i].key;
          final meta = entries[i].value;
          final isLast = i == entries.length - 1;
          return Column(
            children: [
              SwitchListTile(
                value: _toggleFeatures[code] ?? false,
                onChanged: (val) =>
                    setState(() => _toggleFeatures[code] = val),
                activeThumbColor: AppColors.primaryFg,
                activeTrackColor: AppColors.primary,
                inactiveThumbColor: AppColors.textDisabled,
                inactiveTrackColor: AppColors.surfaceVariant,
                title: Text(
                  meta[0],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  meta[1],
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              ),
              if (!isLast) _Divider(),
            ],
          );
        }),
      ),
    );
  }

  // Limits section

  Widget _buildLimitsSection() {
    final entries = _limitMeta.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final code = entries[i].key;
          final meta = entries[i].value;
          final isFirst = i == 0;
          final isLast = i == entries.length - 1;
          return Column(
            children: [
              _LimitField(
                label: meta[0],
                hint: meta[1],
                value: _limitValues[code] ?? '',
                onChanged: (val) =>
                    setState(() => _limitValues[code] = val),
                isFirst: isFirst,
                isLast: isLast,
              ),
              if (!isLast) _Divider(),
            ],
          );
        }),
      ),
    );
  }

  // Save button

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryFg,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryFg,
                  ),
                )
              : Text(
                  isEditing ? 'Save Changes' : 'Create Plan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

// Helper widgets

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.divider);
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool isFirst;
  final bool isLast;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    this.keyboardType,
    this.maxLines = 1,
    this.isFirst = false,
    this.isLast = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixText: prefix,
              prefixStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              hintStyle: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              errorStyle: const TextStyle(color: AppColors.error, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitField extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final bool isFirst;
  final bool isLast;

  const _LimitField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              helperText: 'Leave blank for unlimited',
              hintStyle: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
              helperStyle: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 11,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CycleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryFg
                : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
