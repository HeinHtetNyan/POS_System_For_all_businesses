import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/subscription_provider.dart';
import '../data/subscription_repository.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(subscriptionProvider.notifier).setTab(_tabController.index);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    await notifier.load();
    final tab = ref.read(subscriptionProvider).tab;
    if (tab == 1) await notifier.loadPaymentProofs();
    if (tab == 2) await notifier.loadBillingHistory();
  }

  void _showSubmitProofSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SubmitProofSheet(
        onSubmitted: () {
          ref.read(subscriptionProvider.notifier).loadPaymentProofs();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Subscription',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (state.tab == 1)
            TextButton.icon(
              onPressed: () => _showSubmitProofSheet(context),
              icon: const Icon(Icons.upload_outlined,
                  size: 16, color: AppColors.primary),
              label: const Text('Submit Proof',
                  style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: AppColors.divider,
          tabs: const [
            Tab(text: 'Current Plan'),
            Tab(text: 'Proofs'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: state.isLoading && state.statusData == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.error != null && state.statusData == null
              ? _ErrorView(
                  error: state.error!,
                  onRetry: () => ref.read(subscriptionProvider.notifier).load(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _CurrentPlanTab(
                      statusData: state.statusData ?? {},
                      plans: state.plans,
                      isLoading: state.isLoading,
                      onRefresh: _onRefresh,
                      // H-35: navigate to pricing screen instead of calling requestUpgrade
                      onNavigateToPricing: () => context.push('/pricing'),
                      // H-38: downgrade via provider
                      onDowngrade: (planId) => ref
                          .read(subscriptionProvider.notifier)
                          .requestDowngrade(planId),
                    ),
                    _PaymentProofsTab(
                      proofs: state.paymentProofs,
                      isLoading: state.proofsLoading,
                      onRefresh: _onRefresh,
                      onSubmit: () => _showSubmitProofSheet(context),
                    ),
                    // H-37: pass error and retry to billing history tab
                    _BillingHistoryTab(
                      billingHistory: state.billingHistory,
                      onRefresh: _onRefresh,
                      error: state.error,
                      onRetry: () =>
                          ref.read(subscriptionProvider.notifier).loadBillingHistory(),
                    ),
                  ],
                ),
    );
  }
}

// Payment Proofs Tab

class _PaymentProofsTab extends StatelessWidget {
  final List<Map<String, dynamic>> proofs;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onSubmit;

  const _PaymentProofsTab({
    required this.proofs,
    required this.isLoading,
    required this.onRefresh,
    required this.onSubmit,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    // H-39: wrap in ContentWrapper
    return ContentWrapper(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: onRefresh,
        child: proofs.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        const Text('No payment proofs yet',
                            style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.primaryFg),
                          onPressed: onSubmit,
                          icon: const Icon(Icons.upload_outlined, size: 16),
                          label: const Text('Submit Proof'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: proofs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = proofs[i];
                  final status = p['status'] as String? ?? 'PENDING';
                  final reviewed = p['reviewed_at'] != null;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: status == 'REJECTED'
                              ? AppColors.error.withValues(alpha: 0.3)
                              : status == 'APPROVED'
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${p['amount'] ?? '0'} ${p['currency'] ?? 'MMK'}',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                                  if (p['target_plan_name'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '→ ${p['target_plan_name']}',
                                        style: const TextStyle(
                                            color: AppColors.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  if (p['reference_number'] != null)
                                    Text('Ref: ${p['reference_number']}',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(status)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        if (reviewed) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: status == 'APPROVED'
                                  ? AppColors.successLight
                                  : AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status == 'APPROVED'
                                      ? '✓ Approved'
                                      : '✗ Rejected',
                                  style: TextStyle(
                                      color: status == 'APPROVED'
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (p['review_notes'] != null &&
                                    (p['review_notes'] as String).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      p['review_notes'] as String,
                                      style: TextStyle(
                                          color: status == 'APPROVED'
                                              ? AppColors.success
                                              : AppColors.error,
                                          fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// Submit Proof Bottom Sheet

// H-40: Convert to ConsumerStatefulWidget
class _SubmitProofSheet extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _SubmitProofSheet({required this.onSubmitted});

  @override
  ConsumerState<_SubmitProofSheet> createState() => _SubmitProofSheetState();
}

class _SubmitProofSheetState extends ConsumerState<_SubmitProofSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  XFile? _pickedFile;
  bool _uploading = false;
  bool _submitting = false;
  String? _uploadedUrl;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _pickedFile = file;
        _uploadedUrl = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_amountCtrl.text.trim().isEmpty || _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Amount and file are required'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _uploading = true);
    try {
      // H-40: use ref.read(subscriptionRepositoryProvider) instead of direct instantiation
      final repo = ref.read(subscriptionRepositoryProvider);
      _uploadedUrl ??= await repo.uploadProofFile(_pickedFile!.path);
      setState(() {
        _uploading = false;
        _submitting = true;
      });

      await repo.submitPaymentProof({
        'amount': _amountCtrl.text.trim(),
        'currency': 'MMK',
        if (_refCtrl.text.trim().isNotEmpty)
          'reference_number': _refCtrl.text.trim(),
        'proof_file_url': _uploadedUrl,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment proof submitted'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _uploading || _submitting;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Submit Payment Proof',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SheetField(
              label: 'Amount *',
              controller: _amountCtrl,
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Reference Number',
              controller: _refCtrl,
              hint: 'TXN-12345',
            ),
            const SizedBox(height: 12),
            const Text('Receipt File *',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: busy ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _pickedFile != null
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.divider,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _pickedFile != null
                    ? Row(
                        children: [
                          const Icon(Icons.image_outlined,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedFile!.name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Text('Change',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12)),
                        ],
                      )
                    : const Center(
                        child: Text('Tap to select image',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: busy ? null : _submit,
                child: busy
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryFg),
                          ),
                          const SizedBox(width: 8),
                          Text(_uploading ? 'Uploading…' : 'Submitting…'),
                        ],
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  const _SheetField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textDisabled, fontSize: 13),
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
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// Current Plan Tab

class _CurrentPlanTab extends ConsumerStatefulWidget {
  final Map<String, dynamic> statusData;
  final List<Map<String, dynamic>> plans;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  // H-35: navigate to pricing screen
  final VoidCallback onNavigateToPricing;
  // H-38: downgrade callback
  final void Function(String planId) onDowngrade;

  const _CurrentPlanTab({
    required this.statusData,
    required this.plans,
    required this.isLoading,
    required this.onRefresh,
    required this.onNavigateToPricing,
    required this.onDowngrade,
  });

  @override
  ConsumerState<_CurrentPlanTab> createState() => _CurrentPlanTabState();
}

class _CurrentPlanTabState extends ConsumerState<_CurrentPlanTab> {
  @override
  Widget build(BuildContext context) {
    // H-39: wrap in ContentWrapper
    return ContentWrapper(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: widget.onRefresh,
        child: ListView(
          children: [
            // Plan summary card
            _SectionHeader(title: 'PLAN OVERVIEW'),
            _PlanSummaryCard(statusData: widget.statusData),

            // Auto-renewal toggle (H-36: disabled — endpoint not yet available)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Auto-Renewal',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // H-36: subtitle indicates feature is coming soon
                subtitle: const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                value: false,
                // H-36: disabled — backend endpoint does not exist yet
                onChanged: null,
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                secondary: const Icon(
                  Icons.autorenew_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // Usage stats
            _SectionHeader(title: 'USAGE'),
            _UsageStatsCard(statusData: widget.statusData),

            // Available plans
            if (widget.plans.isNotEmpty) ...[
              _SectionHeader(title: 'AVAILABLE PLANS'),
              ...widget.plans.map((plan) => _PlanCard(
                    plan: plan,
                    statusData: widget.statusData,
                    // H-35: navigate to pricing screen for upgrade
                    onNavigateToPricing: widget.onNavigateToPricing,
                    // H-38: downgrade callback
                    onDowngrade: widget.onDowngrade,
                  )),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final Map<String, dynamic> statusData;

  const _PlanSummaryCard({required this.statusData});

  @override
  Widget build(BuildContext context) {
    final planName =
        statusData['plan_name']?.toString() ?? statusData['plan']?.toString() ?? '—';
    final status = statusData['status']?.toString() ?? 'unknown';
    final trialEndsAt = statusData['trial_ends_at']?.toString();
    final expiresAt = statusData['expires_at']?.toString() ??
        statusData['current_period_end']?.toString();

    String? dateLabel;
    String? dateValue;

    if (trialEndsAt != null && trialEndsAt.isNotEmpty) {
      dateLabel = 'Trial ends';
      dateValue = _formatDate(trialEndsAt);
    } else if (expiresAt != null && expiresAt.isNotEmpty) {
      dateLabel = 'Renews / expires';
      dateValue = _formatDate(expiresAt);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          if (dateLabel != null && dateValue != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  status.toUpperCase() == 'TRIAL'
                      ? Icons.hourglass_top_rounded
                      : Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '$dateLabel: ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  dateValue,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _UsageStatsCard extends StatelessWidget {
  final Map<String, dynamic> statusData;

  const _UsageStatsCard({required this.statusData});

  @override
  Widget build(BuildContext context) {
    // Attempt both flat and nested shapes the backend may return
    final usage = statusData['usage'] as Map<String, dynamic>? ?? statusData;
    final limits = statusData['limits'] as Map<String, dynamic>? ?? {};

    final branches =
        usage['branches_count'] ?? usage['branches'] ?? usage['branch_count'] ?? 0;
    final users =
        usage['users_count'] ?? usage['users'] ?? usage['user_count'] ?? 0;
    final products =
        usage['products_count'] ?? usage['products'] ?? usage['product_count'] ?? 0;

    final maxBranches = limits['max_branches'] ??
        statusData['max_branches'] ??
        statusData['branches_limit'];
    final maxUsers =
        limits['max_users'] ?? statusData['max_users'] ?? statusData['users_limit'];
    final maxProducts = limits['max_products'] ??
        statusData['max_products'] ??
        statusData['products_limit'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _UsageStat(
            icon: Icons.store_outlined,
            label: 'Branches',
            used: _toInt(branches),
            max: _toIntOrNull(maxBranches),
          ),
          _VerticalDivider(),
          _UsageStat(
            icon: Icons.people_outline,
            label: 'Users',
            used: _toInt(users),
            max: _toIntOrNull(maxUsers),
          ),
          _VerticalDivider(),
          _UsageStat(
            icon: Icons.inventory_2_outlined,
            label: 'Products',
            used: _toInt(products),
            max: _toIntOrNull(maxProducts),
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }
}

class _UsageStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int used;
  final int? max;

  const _UsageStat({
    required this.icon,
    required this.label,
    required this.used,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    final limitText = max == null ? '∞' : '$max';
    final double ratio =
        max == null ? 1.0 : (used / max!).clamp(0.0, 1.0);
    final Color barColor = max == null
        ? AppColors.success
        : ratio >= 0.9
            ? AppColors.error
            : ratio >= 0.7
                ? AppColors.warning
                : AppColors.success;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            '$used / $limitText',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

// H-35 + H-38: Plan card with Upgrade (navigate to pricing) and Downgrade buttons
class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> statusData;
  final VoidCallback onNavigateToPricing;
  final void Function(String planId) onDowngrade;

  const _PlanCard({
    required this.plan,
    required this.statusData,
    required this.onNavigateToPricing,
    required this.onDowngrade,
  });

  @override
  Widget build(BuildContext context) {
    final planId = plan['id']?.toString() ?? plan['plan_id']?.toString() ?? '';
    final name = plan['name']?.toString() ?? '—';
    final price = plan['price']?.toString() ?? plan['monthly_price']?.toString();
    final currency = plan['currency']?.toString() ?? 'MMK';
    final currentPlanId =
        statusData['plan_id']?.toString() ?? '';
    final isCurrent = planId == currentPlanId;

    // H-38: determine if this plan is cheaper (downgrade)
    final currentPrice = double.tryParse(
          statusData['plan_price']?.toString() ??
              statusData['price']?.toString() ??
              '',
        ) ??
        0.0;
    final thisPlanPrice = double.tryParse(price ?? '') ?? 0.0;
    final isDowngrade = !isCurrent && thisPlanPrice < currentPrice && currentPrice > 0;

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.divider,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$price $currency / mo',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          // Features
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // H-35: Upgrade navigates to pricing screen
          // H-38: Downgrade button shown for cheaper plans
          if (!isCurrent) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isDowngrade
                  ? OutlinedButton(
                      onPressed: planId.isNotEmpty ? () => onDowngrade(planId) : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Downgrade'),
                    )
                  : ElevatedButton(
                      onPressed: onNavigateToPricing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Upgrade'),
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

// Billing History Tab

class _BillingHistoryTab extends StatelessWidget {
  final List<Map<String, dynamic>> billingHistory;
  final Future<void> Function() onRefresh;
  // H-37: error state and retry
  final String? error;
  final VoidCallback onRetry;

  const _BillingHistoryTab({
    required this.billingHistory,
    required this.onRefresh,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // H-39: wrap in ContentWrapper
    return ContentWrapper(
      child: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: onRefresh,
        child: billingHistory.isEmpty
            // H-37: show error card when empty AND there is an error
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  if (error != null)
                    _BillingErrorCard(error: error!, onRetry: onRetry)
                  else
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppColors.textDisabled),
                          SizedBox(height: 12),
                          Text(
                            'No billing records yet',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: billingHistory.length,
                itemBuilder: (context, index) {
                  final item = billingHistory[index];
                  return _BillingRow(item: item);
                },
              ),
      ),
    );
  }
}

// H-37: error card with retry button for billing history
class _BillingErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _BillingErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 36),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillingRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _BillingRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(item['created_at']?.toString() ??
        item['date']?.toString() ??
        item['billing_date']?.toString() ??
        '');
    final amount = item['amount']?.toString() ?? '0';
    final currency = item['currency']?.toString() ?? 'MMK';
    final status =
        item['status']?.toString() ?? item['payment_status']?.toString() ?? 'pending';
    final description = item['description']?.toString() ??
        item['plan_name']?.toString() ??
        'Subscription';
    final invoiceUrl = item['invoice_url'] as String? ?? item['receipt_url'] as String?;
    final hasInvoice = invoiceUrl != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_outlined,
              size: 20, color: AppColors.textSecondary),
        ),
        title: Text(
          description,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: status),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$amount $currency',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasInvoice) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(invoiceUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.download_outlined,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// Shared helpers

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
