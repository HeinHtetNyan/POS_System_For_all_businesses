import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _PlanModel {
  final String id;
  final String name;
  final String? description;
  final double monthlyPrice;
  final double? yearlyPrice;
  final String billingCycle;
  final bool isActive;
  final Map<String, dynamic> entitlements;

  const _PlanModel({
    required this.id,
    required this.name,
    this.description,
    required this.monthlyPrice,
    this.yearlyPrice,
    required this.billingCycle,
    required this.isActive,
    required this.entitlements,
  });

  factory _PlanModel.fromJson(Map<String, dynamic> json) {
    final raw = json['entitlements'];
    Map<String, dynamic> ents = {};
    if (raw is Map) {
      ents = Map<String, dynamic>.from(raw);
    } else if (raw is List) {
      for (final e in raw) {
        if (e is Map && e['feature'] != null) {
          ents[e['feature'] as String] = e['value'] ?? e['limit'] ?? true;
        }
      }
    }
    return _PlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble() ??
          0.0,
      yearlyPrice: (json['yearly_price'] as num?)?.toDouble(),
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      isActive: json['is_active'] as bool? ?? true,
      entitlements: ents,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class _PlansState {
  final bool isLoading;
  final String? error;
  final List<_PlanModel> plans;

  const _PlansState({
    this.isLoading = false,
    this.error,
    this.plans = const [],
  });

  _PlansState copyWith({
    bool? isLoading,
    String? error,
    List<_PlanModel>? plans,
  }) =>
      _PlansState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        plans: plans ?? this.plans,
      );
}

class _PlansNotifier extends StateNotifier<_PlansState> {
  _PlansNotifier() : super(const _PlansState());

  Future<void> load({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp = await apiClient.get('/subscriptions/plans');
      final data = resp.data;
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List;
      } else {
        list = [];
      }
      final plans =
          list.map((e) => _PlanModel.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(isLoading: false, plans: plans);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final _resellerPlansProvider =
    StateNotifierProvider.autoDispose<_PlansNotifier, _PlansState>(
  (_) => _PlansNotifier(),
);

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _featureLabels = <String, String>{
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
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerPlansScreen extends ConsumerStatefulWidget {
  const ResellerPlansScreen({super.key});

  @override
  ConsumerState<ResellerPlansScreen> createState() =>
      _ResellerPlansScreenState();
}

class _ResellerPlansScreenState extends ConsumerState<ResellerPlansScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_resellerPlansProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_resellerPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Subscription Plans',
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
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () =>
            ref.read(_resellerPlansProvider.notifier).load(refresh: true),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(_PlansState state) {
    if (state.isLoading) {
      return const ShimmerList(itemCount: 4, itemHeight: 260);
    }
    if (state.error != null) {
      return ErrorView(
        message: state.error!,
        onRetry: () =>
            ref.read(_resellerPlansProvider.notifier).load(refresh: true),
      );
    }
    if (state.plans.isEmpty) {
      return const EmptyView(
        icon: Icons.subscriptions_outlined,
        title: 'No plans available',
        subtitle: 'Subscription plans will appear here once configured.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: state.plans.length,
      itemBuilder: (_, i) => _PlanCard(plan: state.plans[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan Card
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final _PlanModel plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: plan.isActive
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      if (plan.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          plan.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(isActive: plan.isActive),
                    const SizedBox(height: 8),
                    _PriceTag(
                      monthlyPrice: plan.monthlyPrice,
                      yearlyPrice: plan.yearlyPrice,
                      billingCycle: plan.billingCycle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(height: 1, color: AppColors.divider),

          // Features grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: _FeaturesGrid(entitlements: plan.entitlements),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price Tag
// ---------------------------------------------------------------------------

class _PriceTag extends StatelessWidget {
  final double monthlyPrice;
  final double? yearlyPrice;
  final String billingCycle;

  const _PriceTag({
    required this.monthlyPrice,
    this.yearlyPrice,
    required this.billingCycle,
  });

  String get _cycleLabel {
    switch (billingCycle.toLowerCase()) {
      case 'yearly':
      case 'annual':
        return '/ year';
      case 'quarterly':
        return '/ quarter';
      default:
        return '/ month';
    }
  }

  double get _displayPrice {
    if ((billingCycle.toLowerCase() == 'yearly' ||
            billingCycle.toLowerCase() == 'annual') &&
        yearlyPrice != null) {
      return yearlyPrice!;
    }
    return monthlyPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          CurrencyFormatter.format(_displayPrice),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.primary,
          ),
        ),
        Text(
          _cycleLabel,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Features Grid
// ---------------------------------------------------------------------------

class _FeaturesGrid extends StatelessWidget {
  final Map<String, dynamic> entitlements;
  const _FeaturesGrid({required this.entitlements});

  @override
  Widget build(BuildContext context) {
    if (entitlements.isEmpty) {
      return const Text(
        'No feature details available.',
        style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
      );
    }

    // Build ordered list: known features first (in _featureLabels order), then unknowns
    final orderedKeys = [
      ..._featureLabels.keys.where((k) => entitlements.containsKey(k)),
      ...entitlements.keys.where((k) => !_featureLabels.containsKey(k)),
    ];

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: orderedKeys.map((key) {
        final label = _featureLabels[key] ??
            key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
        final raw = entitlements[key];
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 64) / 2,
          child: _FeatureRow(
            label: label,
            value: raw,
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature Row
// ---------------------------------------------------------------------------

class _FeatureRow extends StatelessWidget {
  final String label;
  final dynamic value;
  const _FeatureRow({required this.label, required this.value});

  bool get _isEnabled {
    if (value is bool) return value as bool;
    if (value is int) return (value as int) != 0;
    if (value is String) {
      final s = (value as String).toLowerCase();
      return s != 'false' && s != '0' && s != 'disabled' && s.isNotEmpty;
    }
    return value != null;
  }

  String get _displayValue {
    if (value is bool) return (value as bool) ? '✓' : '✗';
    if (value is int) {
      final n = value as int;
      if (n == 0) return '∞';
      if (n < 0) return '✗';
      // Format with commas for large numbers
      final fmt = n.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      return fmt;
    }
    if (value is double) {
      final d = value as double;
      if (d == 0) return '∞';
      if (d < 0) return '✗';
      return d.toStringAsFixed(0);
    }
    if (value == null) return '✗';
    final s = value.toString();
    if (s.toLowerCase() == 'true') return '✓';
    if (s.toLowerCase() == 'false') return '✗';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _isEnabled;
    final textColor =
        enabled ? AppColors.textPrimary : AppColors.textDisabled;
    final valueColor = enabled ? AppColors.primary : AppColors.textDisabled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 14,
            color: enabled
                ? AppColors.success
                : AppColors.textDisabled,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _displayValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
