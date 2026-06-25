import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/reseller_repository.dart';
import '../providers/reseller_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_view.dart';

final _referralStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(resellerRepositoryProvider).getReferralStats();
});

class ResellerDashboardScreen extends ConsumerStatefulWidget {
  const ResellerDashboardScreen({super.key});

  @override
  ConsumerState<ResellerDashboardScreen> createState() =>
      _ResellerDashboardScreenState();
}

class _ResellerDashboardScreenState
    extends ConsumerState<ResellerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resellerDashboardProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resellerDashboardProvider);
    final referralStats = ref.watch(_referralStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Reseller Portal',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref
              .read(resellerDashboardProvider.notifier)
              .load(refresh: true);
          ref.invalidate(_referralStatsProvider);
        },
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => ref
                        .read(resellerDashboardProvider.notifier)
                        .load(refresh: true),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // REFERRAL PERFORMANCE section
                      const Text(
                        'Referral Performance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      referralStats.when(
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                        error: (_, __) => LayoutBuilder(
                          builder: (_, c) => GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: Responsive.gridCols(
                              c.maxWidth,
                              phone: 2,
                              tablet: 4,
                              wide: 4,
                            ),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: const [
                              _StatCard(
                                title: 'Total Referrals',
                                value: '--',
                                icon: Icons.people_outline,
                                color: Colors.amber,
                              ),
                              _StatCard(
                                title: 'Converted',
                                subtitle: 'Paying customers',
                                value: '--',
                                icon: Icons.how_to_reg_outlined,
                                color: AppColors.success,
                              ),
                              _StatCard(
                                title: 'In Trial',
                                subtitle: 'Active trials',
                                value: '--',
                                icon: Icons.hourglass_empty_outlined,
                                color: AppColors.primary,
                              ),
                              _StatCard(
                                title: 'Conversion Rate',
                                subtitle: 'Trial → paid',
                                value: '--',
                                icon: Icons.trending_up_outlined,
                                color: AppColors.secondary,
                              ),
                            ],
                          ),
                        ),
                        data: (stats) {
                          final totalReferrals =
                              (stats['total_referrals'] as int? ?? 0)
                                  .toString();
                          final converted =
                              (stats['converted_referrals'] as int? ?? 0)
                                  .toString();
                          final inTrial =
                              (stats['trial_referrals'] as int? ?? 0)
                                  .toString();
                          final rate =
                              (stats['conversion_rate'] as num? ?? 0);
                          final rateStr =
                              '${rate.toStringAsFixed(1)}%';

                          return LayoutBuilder(
                            builder: (_, c) => GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: Responsive.gridCols(
                                c.maxWidth,
                                phone: 2,
                                tablet: 4,
                                wide: 4,
                              ),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.6,
                              children: [
                                _StatCard(
                                  title: 'Total Referrals',
                                  value: totalReferrals,
                                  icon: Icons.people_outline,
                                  color: Colors.amber,
                                ),
                                _StatCard(
                                  title: 'Converted',
                                  subtitle: 'Paying customers',
                                  value: converted,
                                  icon: Icons.how_to_reg_outlined,
                                  color: AppColors.success,
                                ),
                                _StatCard(
                                  title: 'In Trial',
                                  subtitle: 'Active trials',
                                  value: inTrial,
                                  icon: Icons.hourglass_empty_outlined,
                                  color: AppColors.primary,
                                ),
                                _StatCard(
                                  title: 'Conversion Rate',
                                  subtitle: 'Trial → paid',
                                  value: rateStr,
                                  icon: Icons.trending_up_outlined,
                                  color: AppColors.secondary,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // WALLET / CLIENT stats grid
                      if (state.stats != null) ...[
                        LayoutBuilder(
                          builder: (_, c) => GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: Responsive.gridCols(
                              c.maxWidth,
                              phone: 2,
                              tablet: 4,
                              wide: 4,
                            ),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: [
                              _StatCard(
                                title: 'Total Clients',
                                value: (state.stats!['total_clients'] as int? ??
                                        0)
                                    .toString(),
                                icon: Icons.business_outlined,
                                color: AppColors.primary,
                              ),
                              _StatCard(
                                title: 'Active Clients',
                                value: (state.stats!['active_clients'] as int? ??
                                        0)
                                    .toString(),
                                icon: Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                              _StatCard(
                                title: 'Total Commissions',
                                value: CurrencyFormatter.format(
                                    (state.stats!['total_commissions'] as num?)
                                            ?.toDouble() ??
                                        0),
                                icon: Icons.monetization_on_outlined,
                                color: AppColors.secondary,
                              ),
                              _StatCard(
                                title: 'Wallet Balance',
                                value: CurrencyFormatter.format(
                                    (state.stats!['wallet_balance'] as num?)
                                            ?.toDouble() ??
                                        0),
                                icon: Icons.account_balance_wallet_outlined,
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Quick actions
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Wallet',
                              color: AppColors.primary,
                              onTap: () => context.push('/reseller/wallet'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.business_outlined,
                              label: 'My Clients',
                              color: AppColors.secondary,
                              onTap: () => context.push('/reseller/referrals'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.money_outlined,
                              label: 'Commissions',
                              color: AppColors.success,
                              onTap: () =>
                                  context.push('/reseller/commissions'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
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
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
