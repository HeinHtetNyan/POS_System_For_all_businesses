import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  Dio get _dio => apiClient.dio;

  late Future<List<Map<String, dynamic>>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = _fetchPlans();
  }

  Future<List<Map<String, dynamic>>> _fetchPlans() async {
    try {
      final response = await _dio.get('/subscriptions/plans');
      final data = response.data;

      List<dynamic> rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map && data.containsKey('items')) {
        rawList = data['items'] as List<dynamic>? ?? [];
      } else if (data is Map && data.containsKey('plans')) {
        rawList = data['plans'] as List<dynamic>? ?? [];
      } else {
        rawList = [];
      }

      return rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((p) => p['is_active'] == true || p['is_active'] == null)
          .toList();
    } on DioException catch (e) {
      // 401 from public endpoint — treat as empty list gracefully
      if (e.response?.statusCode == 401) {
        return [];
      }
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _plansFuture = _fetchPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Subscription Plans',
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: _retry);
          }

          final plans = snapshot.data ?? [];

          if (plans.isEmpty) {
            return _ErrorState(
              message: 'No plans available at this time.',
              onRetry: _retry,
            );
          }

          // Determine highlighted plan index
          final highlightIndex = _findHighlightIndex(plans);

          // H-39: wrap in ContentWrapper for tablet responsiveness
          return ContentWrapper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Choose Your Plan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scale your business with the right features',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Plan cards
                  ...plans.asMap().entries.map((entry) {
                    final index = entry.key;
                    final plan = entry.value;
                    final isHighlighted = index == highlightIndex;
                    return _PlanCard(
                      plan: plan,
                      isHighlighted: isHighlighted,
                      onGetStarted: (planId) {
                        context.push('/subscribe?plan_id=$planId');
                      },
                    );
                  }),

                  const SizedBox(height: 24),

                  // Footer note
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'All prices are in Myanmar Kyat (MMK). '
                      'Cancel or change plans at any time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _findHighlightIndex(List<Map<String, dynamic>> plans) {
    if (plans.length < 2) return 0;
    // Pick the second plan (index 1) or the most expensive
    double maxPrice = -1;
    int maxIndex = 1; // default to second
    for (int i = 0; i < plans.length; i++) {
      final raw = plans[i]['price'];
      final price = double.tryParse(raw?.toString() ?? '') ?? 0.0;
      if (price > maxPrice) {
        maxPrice = price;
        maxIndex = i;
      }
    }
    // If all prices are equal or zero, use index 1
    return maxIndex > 0 ? maxIndex : 1;
  }
}

// Plan Card

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isHighlighted;
  final void Function(String planId) onGetStarted;

  const _PlanCard({
    required this.plan,
    required this.isHighlighted,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final planId = plan['id']?.toString() ?? '';
    final name = plan['name']?.toString() ?? 'Plan';
    final rawPrice = plan['price'];
    final double price =
        double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;
    final cycle = (plan['billing_cycle']?.toString() ?? 'MONTHLY').toUpperCase();
    final cycleLabel = cycle == 'YEARLY' ? 'year' : 'month';
    final description = plan['description']?.toString();

    // Parse entitlements
    final rawEntitlements = plan['entitlements'];
    final List<Map<String, dynamic>> entitlements = [];
    if (rawEntitlements is List) {
      for (final e in rawEntitlements) {
        if (e is Map) {
          entitlements.add(Map<String, dynamic>.from(e));
        }
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.divider,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Most Popular badge
          if (isHighlighted)
            Container(
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 14, color: AppColors.primaryFg),
                  SizedBox(width: 4),
                  Text(
                    'Most Popular',
                    style: TextStyle(
                      color: AppColors.primaryFg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MMK ${_formatPrice(price)}',
                      style: TextStyle(
                        color: isHighlighted
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '/ $cycleLabel',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],

                // Entitlement chips
                if (entitlements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entitlements
                        .map((e) => _EntitlementChip(
                              entitlement: e,
                              highlighted: isHighlighted,
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 20),

                // Get Started button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: planId.isNotEmpty
                        ? () => onGetStarted(planId)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHighlighted
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      foregroundColor: isHighlighted
                          ? AppColors.primaryFg
                          : AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: isHighlighted
                            ? BorderSide.none
                            : const BorderSide(color: AppColors.divider),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: isHighlighted ? 2 : 0,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      // Whole number — format with commas
      final intVal = price.toInt();
      final s = intVal.toString();
      final buffer = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) {
          buffer.write(',');
        }
        buffer.write(s[i]);
      }
      return buffer.toString();
    }
    return price.toStringAsFixed(2);
  }
}

// Entitlement Chip

class _EntitlementChip extends StatelessWidget {
  final Map<String, dynamic> entitlement;
  final bool highlighted;

  const _EntitlementChip({
    required this.entitlement,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final featureCode =
        entitlement['feature_code']?.toString() ?? '';
    final enabled = entitlement['enabled'] == true ||
        entitlement['enabled'] == 1;
    final limitValue = entitlement['limit_value'];

    final label = _buildLabel(featureCode, enabled, limitValue);
    final chipColor = enabled
        ? (highlighted
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceVariant)
        : AppColors.errorLight;
    final textColor = enabled
        ? (highlighted ? AppColors.primary : AppColors.textSecondary)
        : AppColors.error;
    final borderColor = enabled
        ? (highlighted
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.divider)
        : AppColors.error.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _buildLabel(String code, bool enabled, dynamic limitValue) {
    final limit = limitValue != null
        ? int.tryParse(limitValue.toString())
        : null;

    switch (code.toLowerCase()) {
      case 'products':
        if (limit != null) return '$limit Products';
        return enabled ? 'Unlimited Products' : 'No Products';
      case 'users':
        if (limit != null) return '$limit Staff';
        return enabled ? 'Unlimited Staff' : 'No Staff';
      case 'branches':
        if (limit != null) return '$limit Branches';
        return enabled ? 'Unlimited Branches' : 'No Branches';
      case 'analytics':
        return enabled ? 'Analytics ✓' : 'Analytics ✗';
      case 'procurement':
        return enabled ? 'Procurement ✓' : 'Procurement ✗';
      default:
        final humanized = code
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');
        if (limit != null) return '$limit $humanized';
        return enabled ? '$humanized ✓' : '$humanized ✗';
    }
  }
}

// Error State

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    this.message = 'Could not load plans. Please try again.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
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
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
