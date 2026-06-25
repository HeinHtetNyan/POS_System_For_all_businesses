import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

// Overview model

class _AdminOverview {
  final int totalTenants;
  final int activeSubscriptions;
  final int trialSubscriptions;
  final int expiredSubscriptions;
  final int totalUsers;
  final int totalBranches;

  const _AdminOverview({
    required this.totalTenants,
    required this.activeSubscriptions,
    required this.trialSubscriptions,
    required this.expiredSubscriptions,
    required this.totalUsers,
    required this.totalBranches,
  });

  factory _AdminOverview.fromJson(Map<String, dynamic> json) => _AdminOverview(
        totalTenants: (json['total_tenants'] as num?)?.toInt() ?? 0,
        activeSubscriptions: (json['active_subscriptions'] as num?)?.toInt() ?? 0,
        trialSubscriptions: (json['trial_subscriptions'] as num?)?.toInt() ?? 0,
        expiredSubscriptions: (json['expired_subscriptions'] as num?)?.toInt() ?? 0,
        totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
        totalBranches: (json['total_branches'] as num?)?.toInt() ?? 0,
      );
}

final _adminOverviewProvider = FutureProvider.autoDispose<_AdminOverview>((_) async {
  final resp = await apiClient.dio.get(ApiEndpoints.adminOverview);
  return _AdminOverview.fromJson(resp.data as Map<String, dynamic>);
});

// Screen

class SuperAdminDashboard extends ConsumerWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(_adminOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.refresh(_adminOverviewProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Banner with amber gradient
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primaryFg,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Platform Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryFg,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Super Admin',
                          style: TextStyle(
                            color: AppColors.primaryFg,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // KPI rows — live data
            overviewAsync.when(
              loading: () => _KpiLoadingRows(),
              error: (_, __) => _KpiErrorRows(),
              data: (ov) => Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _KpiCard(icon: Icons.business_outlined, label: 'Businesses', value: ov.totalTenants.toString(), iconColor: AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(icon: Icons.people_outlined, label: 'Users', value: ov.totalUsers.toString(), iconColor: AppColors.info)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(icon: Icons.account_tree_outlined, label: 'Branches', value: ov.totalBranches.toString(), iconColor: AppColors.secondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _KpiCard(icon: Icons.check_circle_outline, label: 'Active', value: ov.activeSubscriptions.toString(), iconColor: AppColors.success)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(icon: Icons.hourglass_top_outlined, label: 'Trial', value: ov.trialSubscriptions.toString(), iconColor: AppColors.warning)),
                      const SizedBox(width: 12),
                      Expanded(child: _KpiCard(icon: Icons.block_outlined, label: 'Expired', value: ov.expiredSubscriptions.toString(), iconColor: AppColors.error)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Platform Management',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (_, c) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: Responsive.gridCols(
                  c.maxWidth,
                  phone: 3,
                  tablet: 4,
                  wide: 5,
                ),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _NavCard(
                    icon: Icons.business_outlined,
                    label: 'Businesses',
                    color: AppColors.primary,
                    onTap: () => context.push('/admin/tenants'),
                  ),
                  _NavCard(
                    icon: Icons.people_outlined,
                    label: 'Users',
                    color: AppColors.secondary,
                    onTap: () => context.push('/admin/users'),
                  ),
                  _NavCard(
                    icon: Icons.handshake_outlined,
                    label: 'Resellers',
                    color: AppColors.info,
                    onTap: () => context.push('/admin/resellers'),
                  ),
                  _NavCard(
                    icon: Icons.subscriptions_outlined,
                    label: 'Plans',
                    color: AppColors.warning,
                    onTap: () => context.push('/admin/plans'),
                  ),
                  _NavCard(
                    icon: Icons.receipt_outlined,
                    label: 'Subscriptions',
                    color: AppColors.success,
                    onTap: () => context.push('/admin/subscriptions'),
                  ),
                  _NavCard(
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics',
                    color: AppColors.mobilePayColor,
                    onTap: () => context.push('/analytics'),
                  ),
                  _NavCard(
                    icon: Icons.devices_outlined,
                    label: 'Devices',
                    color: AppColors.cardColor,
                    onTap: () => context.push('/admin/devices'),
                  ),
                  _NavCard(
                    icon: Icons.history_outlined,
                    label: 'Audit Logs',
                    color: AppColors.textSecondary,
                    onTap: () => context.push('/admin/audit'),
                  ),
                  _NavCard(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    color: AppColors.textSecondary,
                    onTap: () => context.push('/admin/notifications'),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

// Loading/Error placeholder rows

class _KpiLoadingRows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(3, (i) => Expanded(
            child: Container(
              height: 72,
              margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
          )),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(3, (i) => Expanded(
            child: Container(
              height: 72,
              margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
            ),
          )),
        ),
      ],
    );
  }
}

class _KpiErrorRows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _KpiCard(icon: Icons.business_outlined, label: 'Businesses', value: '—', iconColor: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(icon: Icons.people_outlined, label: 'Users', value: '—', iconColor: AppColors.info)),
        const SizedBox(width: 12),
        Expanded(child: _KpiCard(icon: Icons.subscriptions_outlined, label: 'Subs', value: '—', iconColor: AppColors.success)),
      ],
    );
  }
}

// KPI card

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
