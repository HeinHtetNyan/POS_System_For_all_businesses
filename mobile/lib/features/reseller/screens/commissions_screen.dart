import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reseller_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/reseller_wallet_model.dart';

class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key});

  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends ConsumerState<CommissionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(resellerCommissionsProvider.notifier).load();
      ref.read(resellerReferralsProvider.notifier).load();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(resellerCommissionsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resellerCommissionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Commissions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.divider),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Commissions'),
                  Tab(text: 'Referred Clients'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: flat commission list
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref
                .read(resellerCommissionsProvider.notifier)
                .load(refresh: true),
            child: state.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.error != null
                    ? ErrorView(
                        message: state.error!,
                        onRetry: () => ref
                            .read(resellerCommissionsProvider.notifier)
                            .load(refresh: true),
                      )
                    : state.items.isEmpty
                        ? const EmptyView(
                            icon: Icons.money_outlined,
                            title: 'No commissions yet',
                            subtitle:
                                'Earn commissions when your clients subscribe',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: state.items.length +
                                (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= state.items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary),
                                  ),
                                );
                              }
                              return _CommissionTile(
                                  commission: state.items[i]);
                            },
                          ),
          ),

          // Tab 2: referred clients
          const _ReferredBusinessList(),
        ],
      ),
    );
  }
}

// By Business tab

class _ReferredBusinessList extends ConsumerWidget {
  const _ReferredBusinessList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resellerReferralsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () =>
          ref.read(resellerReferralsProvider.notifier).load(refresh: true),
      child: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : state.error != null
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(resellerReferralsProvider.notifier).load(refresh: true),
                )
              : state.items.isEmpty
                  ? const EmptyView(
                      icon: Icons.business_outlined,
                      title: 'No businesses yet',
                      subtitle:
                          'Businesses that signed up with your referral code appear here',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount:
                          state.items.length + (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= state.items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary),
                            ),
                          );
                        }
                        return _BusinessCommissionCard(
                            referral: state.items[i]);
                      },
                    ),
    );
  }
}

class _BusinessCommissionCard extends StatelessWidget {
  final ReferralModel referral;
  const _BusinessCommissionCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              radius: 22,
              child: Text(
                referral.businessName.isNotEmpty
                    ? referral.businessName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Business name + status badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    referral.businessName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      StatusBadge(status: referral.status),
                      const SizedBox(width: 6),
                      StatusBadge(
                        status: referral.subscriptionStatus,
                        label: referral.subscriptionStatus,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Total commission amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(referral.totalCommissionsEarned),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'total earned',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Commission tile

class _CommissionTile extends StatelessWidget {
  final CommissionModel commission;
  const _CommissionTile({required this.commission});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.successLight,
              radius: 22,
              child: Text(
                commission.tenantName.isNotEmpty
                    ? commission.tenantName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commission.tenantName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${commission.earnedAt.day}/${commission.earnedAt.month}/${commission.earnedAt.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(commission.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(status: commission.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
