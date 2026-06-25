import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';

// Payment method option

class _PaymentMethod {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _PaymentMethod({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _paymentMethods = [
  _PaymentMethod(
    value: 'KPAY',
    label: 'KPay',
    icon: Icons.phone_android_rounded,
    color: AppColors.mobilePayColor,
  ),
  _PaymentMethod(
    value: 'WAVEPAY',
    label: 'WavePay',
    icon: Icons.waves_rounded,
    color: AppColors.info,
  ),
  _PaymentMethod(
    value: 'AYA_PAY',
    label: 'AYA Pay',
    icon: Icons.account_balance_wallet_outlined,
    color: AppColors.success,
  ),
  _PaymentMethod(
    value: 'CB_PAY',
    label: 'CB Pay',
    icon: Icons.credit_card_outlined,
    color: AppColors.cardColor,
  ),
  _PaymentMethod(
    value: 'BANK_TRANSFER',
    label: 'Bank Transfer',
    icon: Icons.account_balance_outlined,
    color: AppColors.primary,
  ),
];

// Screen

class SubscriptionPurchaseScreen extends StatefulWidget {
  final String planId;

  const SubscriptionPurchaseScreen({super.key, required this.planId});

  @override
  State<SubscriptionPurchaseScreen> createState() =>
      _SubscriptionPurchaseScreenState();
}

class _SubscriptionPurchaseScreenState
    extends State<SubscriptionPurchaseScreen> {
  // Dio accessor — never store as field
  Dio get _dio => apiClient.dio;

  // Plan state
  Map<String, dynamic>? _plan;
  bool _isLoadingPlan = true;
  String? _planError;

  // Form state
  XFile? _selectedFile;
  final _notesController = TextEditingController();
  String _selectedPaymentMethod = 'BANK_TRANSFER';
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // API calls

  Future<void> _loadPlan() async {
    setState(() {
      _isLoadingPlan = true;
      _planError = null;
    });
    try {
      final r = await _dio.get('/subscriptions/plans/${widget.planId}');
      setState(() {
        _plan = r.data as Map<String, dynamic>;
        _isLoadingPlan = false;
      });
    } catch (e) {
      setState(() {
        _planError = _extractError(e);
        _isLoadingPlan = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedFile = file);
    }
  }

  Future<void> _submit() async {
    if (_plan == null) return;

    setState(() => _isSubmitting = true);

    try {
      String? proofUrl;

      // Step 1: Upload file if selected
      if (_selectedFile != null) {
        setState(() => _isUploading = true);
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _selectedFile!.path,
            filename: _selectedFile!.name,
          ),
        });
        final uploadResponse = await _dio.post(
          '/subscriptions/payment-proofs/upload',
          data: formData,
        );
        proofUrl = (uploadResponse.data as Map<String, dynamic>)['url']
            as String?;
        setState(() => _isUploading = false);
      }

      // Step 2: Submit payment proof record
      final price = (_plan!['monthly_price'] as num?)?.toDouble() ??
          (_plan!['price'] as num?)?.toDouble() ??
          0.0;

      await _dio.post('/subscriptions/payment-proofs', data: {
        'plan_id': widget.planId,
        'amount': price,
        'payment_method': _selectedPaymentMethod,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        if (proofUrl != null) 'proof_url': proofUrl,
      });

      if (!mounted) return;

      // Step 3: Show success and navigate
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _SuccessDialog(),
      );

      if (!mounted) return;
      context.go('/subscription');
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isSubmitting = false;
      });
      if (!mounted) return;
      _showError(_extractError(e));
    }
  }

  // Helpers

  String _extractError(Object e) {
    if (e is DioException) {
      return AppException.fromDio(e).message;
    }
    return e.toString();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Subscribe to Plan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoadingPlan
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _planError != null
              ? _PlanErrorView(
                  error: _planError!,
                  onRetry: _loadPlan,
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final bool isBusy = _isUploading || _isSubmitting;

    // H-39: wrap in ContentWrapper for tablet responsiveness
    return ContentWrapper(
      child: Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan card
              _sectionHeader('SELECTED PLAN'),
              _PlanCard(plan: _plan!),

              // Payment method selector
              _sectionHeader('PAYMENT METHOD'),
              _PaymentMethodSelector(
                selected: _selectedPaymentMethod,
                onChanged: isBusy
                    ? null
                    : (v) => setState(() => _selectedPaymentMethod = v),
              ),

              // Upload section
              _sectionHeader('PAYMENT PROOF'),
              _UploadSection(
                selectedFile: _selectedFile,
                onTap: isBusy ? null : _pickImage,
                onRemove: isBusy
                    ? null
                    : () => setState(() => _selectedFile = null),
              ),

              // Notes
              _sectionHeader('NOTES (OPTIONAL)'),
              _NotesField(
                controller: _notesController,
                enabled: !isBusy,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),

        // Submit button pinned at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _SubmitBar(
            isUploading: _isUploading,
            isSubmitting: _isSubmitting,
            onSubmit: isBusy ? null : _submit,
          ),
        ),
      ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// Plan Card

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final name = plan['name']?.toString() ?? '—';
    final price = (plan['monthly_price'] as num?)?.toDouble() ??
        (plan['price'] as num?)?.toDouble();
    final currency = plan['currency']?.toString() ?? 'MMK';
    final description = plan['description']?.toString();

    final rawFeatures = plan['features'];
    List<String> features = const [];
    if (rawFeatures is List) {
      features = rawFeatures.map((e) => e.toString()).toList();
    } else if (rawFeatures is Map) {
      features = rawFeatures.entries
          .where((e) => e.value == true || e.value == 1)
          .map((e) => _humanize(e.key.toString()))
          .toList();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (price != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(price, currency: currency),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    ' / month',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 15, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _humanize(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }
}

// Payment Method Selector

class _PaymentMethodSelector extends StatelessWidget {
  final String selected;
  final void Function(String)? onChanged;

  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _paymentMethods.map((pm) {
          final isSelected = selected == pm.value;
          return GestureDetector(
            onTap: onChanged != null ? () => onChanged!(pm.value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? pm.color.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? pm.color
                      : AppColors.divider,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pm.icon,
                    size: 16,
                    color: isSelected ? pm.color : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pm.label,
                    style: TextStyle(
                      color: isSelected
                          ? pm.color
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Upload Section

class _UploadSection extends StatelessWidget {
  final XFile? selectedFile;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _UploadSection({
    required this.selectedFile,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: selectedFile == null
          ? _buildUploadPrompt()
          : _buildThumbnail(),
    );
  }

  Widget _buildUploadPrompt() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload Payment Proof',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to choose an image from gallery',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(selectedFile!.path),
            fit: BoxFit.cover,
          ),
        ),
        // Change button
        Positioned(
          left: 12,
          bottom: 12,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.textPrimary),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.close, size: 16, color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

// Notes Field

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _NotesField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: 3,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Transaction ID, reference number, or any notes...',
          hintStyle: const TextStyle(
            color: AppColors.textDisabled,
            fontSize: 13,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

// Submit Bar

class _SubmitBar extends StatelessWidget {
  final bool isUploading;
  final bool isSubmitting;
  final VoidCallback? onSubmit;

  const _SubmitBar({
    required this.isUploading,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    String label = 'Submit Payment Proof';
    if (isUploading) {
      label = 'Uploading proof...';
    } else if (isSubmitting) {
      label = 'Submitting...';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryFg,
            disabledBackgroundColor:
                AppColors.primary.withValues(alpha: 0.4),
            disabledForegroundColor:
                AppColors.primaryFg.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: (isUploading || isSubmitting)
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryFg,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                )
              : Text(label),
        ),
      ),
    );
  }
}

// Success Dialog

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Proof Submitted',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your payment proof has been submitted for review. '
              'Your subscription will be activated once verified.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryFg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Back to Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Plan Error View

class _PlanErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _PlanErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
