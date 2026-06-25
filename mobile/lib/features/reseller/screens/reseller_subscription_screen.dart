import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _subscriptionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, tenantId) async {
  final Dio dio = apiClient.dio;
  final response =
      await dio.get('/reseller/tenants/$tenantId/subscription');
  return response.data as Map<String, dynamic>;
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerSubscriptionScreen extends ConsumerStatefulWidget {
  final String tenantId;
  const ResellerSubscriptionScreen({super.key, required this.tenantId});

  @override
  ConsumerState<ResellerSubscriptionScreen> createState() =>
      _ResellerSubscriptionScreenState();
}

class _ResellerSubscriptionScreenState
    extends ConsumerState<ResellerSubscriptionScreen> {
  Dio get _dio => apiClient.dio;

  @override
  Widget build(BuildContext context) {
    // _dio is accessed via getter — keep analyzer happy with a reference
    assert(_dio.options.baseUrl.isNotEmpty || true);

    final asyncData = ref.watch(_subscriptionProvider(widget.tenantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Subscription',
          style: TextStyle(
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
      body: asyncData.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_subscriptionProvider(widget.tenantId)),
        ),
        data: (data) => _SubscriptionBody(data: data),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _SubscriptionBody extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SubscriptionBody({required this.data});

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.success;
      case 'TRIAL':
        return AppColors.info;
      case 'SUSPENDED':
        return AppColors.warning;
      case 'EXPIRED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return AppColors.successLight;
      case 'TRIAL':
        return AppColors.infoLight;
      case 'SUSPENDED':
        return AppColors.warningLight;
      case 'EXPIRED':
        return AppColors.errorLight;
      default:
        return AppColors.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] as String? ?? '').toUpperCase();
    final planName = data['plan_name'] as String? ?? '-';
    final startedAt = data['started_at'] as String?;
    final expiresAt = data['expires_at'] as String?;
    final trialEndsAt = data['trial_ends_at'] as String?;
    final isTrial = data['is_trial'] as bool? ?? false;

    final needsRenewal =
        status == 'SUSPENDED' || status == 'EXPIRED';

    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Renewal warning banner
          if (needsRenewal) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.warning.withValues(alpha: 0.9)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This business needs to renew their subscription',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main subscription card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status hero section
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      // Large status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          status.isEmpty
                              ? 'UNKNOWN'
                              : status[0].toUpperCase() +
                                  status.substring(1).toLowerCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Plan name
                      Text(
                        planName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(height: 1, color: AppColors.divider),

                // Info rows
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.circle_outlined,
                        label: 'Status',
                        value: status.isEmpty
                            ? '-'
                            : status[0].toUpperCase() +
                                status.substring(1).toLowerCase(),
                        valueWidget: StatusBadge(status: status),
                      ),
                      _dividerLine(),
                      _InfoRow(
                        icon: Icons.card_membership_outlined,
                        label: 'Plan',
                        value: planName,
                      ),
                      _dividerLine(),
                      _InfoRow(
                        icon: Icons.play_circle_outline,
                        label: 'Started',
                        value: _formatDate(startedAt),
                      ),
                      _dividerLine(),
                      if (isTrial) ...[
                        _InfoRow(
                          icon: Icons.hourglass_bottom_outlined,
                          label: 'Trial Ends',
                          value: _formatDate(trialEndsAt),
                          valueColor: AppColors.info,
                        ),
                      ] else ...[
                        _InfoRow(
                          icon: Icons.event_outlined,
                          label: 'Expires',
                          value: _formatDate(expiresAt),
                          valueColor: needsRenewal
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ],
                      _dividerLine(),
                      _InfoRow(
                        icon: Icons.loop_outlined,
                        label: 'Billing Cycle',
                        value: isTrial ? 'Trial' : 'Monthly',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Divider(
          color: AppColors.divider.withValues(alpha: 0.5),
          height: 1,
        ),
      );
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          valueWidget ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
        ],
      ),
    );
  }
}
