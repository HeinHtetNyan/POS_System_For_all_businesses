import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_provider.dart';

const _kTimezones = [
  'Asia/Rangoon',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Asia/Kolkata',
  'Asia/Dhaka',
  'Asia/Kuala_Lumpur',
  'Asia/Jakarta',
  'Asia/Ho_Chi_Minh',
  'Asia/Seoul',
  'Asia/Tokyo',
];

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const OnboardingWizardScreen({super.key, required this.tenantId});

  @override
  ConsumerState<OnboardingWizardScreen> createState() =>
      _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState
    extends ConsumerState<OnboardingWizardScreen> {
  int _step = 0;
  bool _loading = false;

  final _step1FormKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  String _selectedTimezone = _kTimezones.first;

  final _step2FormKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController(text: 'Main Branch');
  final _branchPhoneController = TextEditingController();
  String? _existingBranchId;
  bool _branchLoaded = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _branchNameController.dispose();
    _branchPhoneController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Future<void> _saveStep1() async {
    if (!_step1FormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await apiClient.patch(
        '/tenants/${widget.tenantId}',
        data: {
          'name': _businessNameController.text.trim(),
          'timezone': _selectedTimezone,
          'currency': 'MMK',
        },
      );
      setState(() => _step = 1);
      await _loadBranch();
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to save business info.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadBranch() async {
    if (_branchLoaded) return;
    try {
      final response =
          await apiClient.get(ApiEndpoints.branches(widget.tenantId));
      final data = response.data;
      List<dynamic> items = [];
      if (data is Map && data.containsKey('items')) {
        items = data['items'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      }
      if (items.isNotEmpty) {
        final first = items.first as Map<String, dynamic>;
        _existingBranchId = first['id']?.toString();
        _branchNameController.text =
            (first['name'] as String?) ?? 'Main Branch';
        _branchPhoneController.text = (first['phone'] as String?) ?? '';
      }
      _branchLoaded = true;
    } catch (_) {
      _branchLoaded = true;
    }
  }

  Future<void> _saveStep2() async {
    if (!_step2FormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final payload = {
        'name': _branchNameController.text.trim(),
        'phone': _branchPhoneController.text.trim().isEmpty
            ? null
            : _branchPhoneController.text.trim(),
      };
      if (_existingBranchId != null) {
        await apiClient.patch(
          '${ApiEndpoints.branches(widget.tenantId)}/$_existingBranchId',
          data: payload,
        );
      } else {
        await apiClient.post(
          ApiEndpoints.branches(widget.tenantId),
          data: {...payload, 'status': 'active'},
        );
      }
      setState(() => _step = 2);
    } on AppException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to save branch info.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      await markOnboardingCompleted(ref);
      if (mounted) context.go('/dashboard/manager');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set up your business',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tell us a bit about your business to get started.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _businessNameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _fieldDecoration('Business Name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedTimezone,
            dropdownColor: AppColors.surfaceVariant,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _fieldDecoration('Timezone'),
            items: _kTimezones
                .map((tz) => DropdownMenuItem(
                      value: tz,
                      child: Text(tz,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedTimezone = v);
            },
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Currency',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'MMK',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Myanmar Kyat — locked',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    const Icon(Icons.lock_outline,
                        color: AppColors.textSecondary, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _saveStep1,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primaryFg),
                    )
                  : const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _loading ? null : () => setState(() => _step = 0),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.textSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Name your main branch',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 42),
            child: Text(
              'This is your primary operating location.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _branchNameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _fieldDecoration('Branch Name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Branch name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _branchPhoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _fieldDecoration('Phone', hint: 'Optional'),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _saveStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primaryFg),
                    )
                  : const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppColors.primary,
          size: 80,
        ),
        const SizedBox(height: 24),
        const Text(
          "You're all set!",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Your business is configured. Start by adding products or opening a cashier session.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryFg,
              disabledBackgroundColor:
                  AppColors.primary.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primaryFg),
                  )
                : const Text('Go to Dashboard'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  64,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildStepIndicator()),
                const SizedBox(height: 36),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _step == 0
                        ? _buildStep1()
                        : _step == 1
                            ? _buildStep2()
                            : _buildStep3(),
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
