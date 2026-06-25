import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../reseller/providers/reseller_provider.dart';

class ResellerDashboard extends ConsumerStatefulWidget {
  const ResellerDashboard({super.key});

  @override
  ConsumerState<ResellerDashboard> createState() => _ResellerDashboardState();
}

class _ResellerDashboardState extends ConsumerState<ResellerDashboard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resellerDashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final dashState = ref.watch(resellerDashboardProvider);
    final stats = dashState.stats;

    final totalClients = stats?['total_clients'] ?? stats?['total_businesses'] ?? 0;
    final walletBalance = (stats?['wallet_balance'] as num? ?? stats?['available_balance'] as num? ?? 0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.read(resellerDashboardProvider.notifier).load(refresh: true),
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner with amber gradient
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
                      Icons.handshake_outlined,
                      color: AppColors.primaryFg,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.firstName ?? 'Reseller'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryFg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Reseller Dashboard',
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

            // KPI row — live data
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.group_outlined,
                    label: 'My Clients',
                    value: dashState.isLoading ? '…' : '$totalClients',
                    iconColor: AppColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet Balance',
                    value: dashState.isLoading ? '…' : CurrencyFormatter.format(walletBalance),
                    iconColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Reseller Portal',
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
                  phone: 2,
                  tablet: 3,
                  wide: 4,
                ),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _ActionCard(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    color: AppColors.primary,
                    onTap: () => context.push('/reseller/dashboard'),
                  ),
                  _ActionCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    color: AppColors.success,
                    onTap: () => context.push('/reseller/wallet'),
                  ),
                  _ActionCard(
                    icon: Icons.business_outlined,
                    label: 'My Clients',
                    color: AppColors.info,
                    onTap: () => context.push('/reseller/referrals'),
                  ),
                  _ActionCard(
                    icon: Icons.money_outlined,
                    label: 'Commissions',
                    color: AppColors.warning,
                    onTap: () => context.push('/reseller/commissions'),
                  ),
                ],
              ),
            ),
          ],
        ),
        ), // ConstrainedBox
        ), // Align
      ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(14),
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
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
