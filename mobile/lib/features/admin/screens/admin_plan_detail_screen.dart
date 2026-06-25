import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/utils/currency_formatter.dart';
// Local model for the detailed plan response

class _PlanEntitlement {
  final String featureCode;
  final bool enabled;
  final int? limitValue;

  const _PlanEntitlement({
    required this.featureCode,
    required this.enabled,
    this.limitValue,
  });

  factory _PlanEntitlement.fromJson(Map<String, dynamic> json) {
    return _PlanEntitlement(
      featureCode: json['feature_code'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      limitValue: json['limit_value'] as int?,
    );
  }
}

class _PlanDetail {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String billingCycle;
  final bool isActive;
  final int trialDays;
  final List<_PlanEntitlement> entitlements;

  const _PlanDetail({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.billingCycle,
    required this.isActive,
    required this.trialDays,
    required this.entitlements,
  });

  factory _PlanDetail.fromJson(Map<String, dynamic> json) {
    final rawEntitlements = json['entitlements'] as List<dynamic>? ?? [];
    return _PlanDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      billingCycle: json['billing_cycle'] as String? ?? 'MONTHLY',
      isActive: json['is_active'] as bool? ?? false,
      trialDays: json['trial_days'] as int? ?? 0,
      entitlements: rawEntitlements
          .map((e) => _PlanEntitlement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Constants

const _legacyMap = {
  'max_products': 'products',
  'max_branches': 'branches',
  'max_users': 'users',
  'max_customers': 'customers',
};

const _featureLabels = {
  'users': 'Staff / Users',
  'branches': 'Branches',
  'products': 'Products',
  'customers': 'Customers',
  'devices': 'Devices',
  'analytics': 'Analytics',
  'procurement': 'Procurement',
  'sync': 'Offline Sync',
  'notifications': 'Notifications',
  'pos': 'POS / Checkout',
  'inventory': 'Inventory',
  'advanced_reports': 'Advanced Reports',
};

// Features that show enabled/disabled toggle style
const _toggleFeatures = {
  'pos',
  'inventory',
  'analytics',
  'advanced_reports',
  'procurement',
  'sync',
  'notifications',
};

// Features that show a numeric limit
const _limitFeatures = {
  'products',
  'branches',
  'users',
  'customers',
  'devices',
};

// Screen

class AdminPlanDetailScreen extends ConsumerStatefulWidget {
  final String planId;
  const AdminPlanDetailScreen({super.key, required this.planId});

  @override
  ConsumerState<AdminPlanDetailScreen> createState() =>
      _AdminPlanDetailScreenState();
}

class _AdminPlanDetailScreenState
    extends ConsumerState<AdminPlanDetailScreen> {
  _PlanDetail? _plan;
  bool _loading = true;
  String? _error;
  bool _toggling = false;

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
      final response =
          await apiClient.get('/subscriptions/plans/${widget.planId}');
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _plan = _PlanDetail.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive() async {
    final plan = _plan;
    if (plan == null) return;

    final deactivating = plan.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          deactivating ? 'Deactivate Plan?' : 'Activate Plan?',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          deactivating
              ? 'Deactivate this plan? Existing subscribers will not be affected immediately.'
              : 'Activate this plan? It will be available for new subscriptions.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              deactivating ? 'Deactivate' : 'Activate',
              style: TextStyle(
                color: deactivating ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _toggling = true);
    try {
      await apiClient.patch(
        '/subscriptions/plans/${widget.planId}',
        data: {'is_active': !plan.isActive},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _plan?.name ?? 'Plan Detail',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
        actions: [
          if (!_loading && _plan != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              tooltip: 'Edit',
              onPressed: () =>
                  context.push('/admin/plans/${widget.planId}/edit'),
            ),
            _toggling
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _toggleActive,
                    child: Text(
                      _plan!.isActive ? 'Deactivate' : 'Activate',
                      style: TextStyle(
                        color: _plan!.isActive
                            ? AppColors.error
                            : AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ],
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _plan == null
                  ? const ErrorView(message: 'Plan not found.')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          _PlanHeaderCard(plan: _plan!),
                          const SizedBox(height: 16),
                          _EntitlementsSection(plan: _plan!),
                        ],
                      ),
                    ),
    );
  }
}

// Plan Header Card

class _PlanHeaderCard extends StatelessWidget {
  final _PlanDetail plan;
  const _PlanHeaderCard({required this.plan});

  String get _cycleLabel =>
      plan.billingCycle == 'YEARLY' ? '/ yr' : '/ mo';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: plan.isActive
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.divider,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                status: plan.isActive ? 'ACTIVE' : 'INACTIVE',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyFormatter.format(plan.price),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 26,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _cycleLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Description
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              plan.description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],

          // Trial days
          if (plan.trialDays > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.info),
                  const SizedBox(width: 6),
                  Text(
                    '${plan.trialDays} day free trial',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Entitlements Section

class _EntitlementsSection extends StatelessWidget {
  final _PlanDetail plan;
  const _EntitlementsSection({required this.plan});

  String _normalizeCode(String code) =>
      _legacyMap[code] ?? code;

  @override
  Widget build(BuildContext context) {
    // Normalize all entitlements
    final entitlements = plan.entitlements.map((e) {
      final normalized = _normalizeCode(e.featureCode);
      return _PlanEntitlement(
        featureCode: normalized,
        enabled: e.enabled,
        limitValue: e.limitValue,
      );
    }).toList();

    // Partition into toggle vs limit
    final toggleItems = entitlements
        .where((e) => _toggleFeatures.contains(e.featureCode))
        .toList();
    final limitItems = entitlements
        .where((e) => _limitFeatures.contains(e.featureCode))
        .toList();

    // Add any unknown codes to toggle list as well
    final knownCodes = {..._toggleFeatures, ..._limitFeatures};
    final otherItems = entitlements
        .where((e) => !knownCodes.contains(e.featureCode))
        .toList();
    toggleItems.addAll(otherItems);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Features & Limits',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.divider),

          // Toggle features
          if (toggleItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'FEATURE FLAGS',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...toggleItems.map(
              (e) => _ToggleFeatureRow(entitlement: e),
            ),
          ],

          // Divider between sections
          if (toggleItems.isNotEmpty && limitItems.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: AppColors.divider, height: 24),
            ),

          // Limit features
          if (limitItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                'USAGE LIMITS',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...limitItems.map(
              (e) => _LimitFeatureRow(entitlement: e),
            ),
          ],

          if (entitlements.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(
                'No entitlements configured for this plan.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Toggle Feature Row

class _ToggleFeatureRow extends StatelessWidget {
  final _PlanEntitlement entitlement;
  const _ToggleFeatureRow({required this.entitlement});

  IconData _iconFor(String code) {
    switch (code) {
      case 'pos':
        return Icons.point_of_sale_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'analytics':
        return Icons.bar_chart_outlined;
      case 'advanced_reports':
        return Icons.assessment_outlined;
      case 'procurement':
        return Icons.local_shipping_outlined;
      case 'sync':
        return Icons.sync_outlined;
      case 'notifications':
        return Icons.notifications_outlined;
      default:
        return Icons.extension_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label =
        _featureLabels[entitlement.featureCode] ?? entitlement.featureCode;
    final enabled = entitlement.enabled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconFor(entitlement.featureCode),
              size: 16,
              color: enabled ? AppColors.primary : AppColors.textDisabled,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.successLight
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: enabled
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.check : Icons.close,
                  size: 12,
                  color: enabled
                      ? AppColors.success
                      : AppColors.textDisabled,
                ),
                const SizedBox(width: 4),
                Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.success
                        : AppColors.textDisabled,
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

// Limit Feature Row

class _LimitFeatureRow extends StatelessWidget {
  final _PlanEntitlement entitlement;
  const _LimitFeatureRow({required this.entitlement});

  IconData _iconFor(String code) {
    switch (code) {
      case 'users':
        return Icons.people_outline;
      case 'branches':
        return Icons.store_outlined;
      case 'products':
        return Icons.inventory_2_outlined;
      case 'customers':
        return Icons.person_outline;
      case 'devices':
        return Icons.devices_outlined;
      default:
        return Icons.tune_outlined;
    }
  }

  String _limitText() {
    final v = entitlement.limitValue;
    if (v == null || v == 0) return 'Unlimited';
    return v.toString();
  }

  bool get _isUnlimited {
    final v = entitlement.limitValue;
    return v == null || v == 0;
  }

  @override
  Widget build(BuildContext context) {
    final label =
        _featureLabels[entitlement.featureCode] ?? entitlement.featureCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconFor(entitlement.featureCode),
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isUnlimited
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isUnlimited
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              _limitText(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isUnlimited
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
