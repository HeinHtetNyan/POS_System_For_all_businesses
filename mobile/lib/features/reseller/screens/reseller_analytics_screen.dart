import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reseller_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _selectedPeriodProvider =
    StateProvider.autoDispose<String>((ref) => '30d');

final _analyticsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, period) {
  final repo = ref.watch(resellerRepositoryProvider);
  return repo.getAnalytics(period: period);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerAnalyticsScreen extends ConsumerWidget {
  const ResellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_selectedPeriodProvider);
    final asyncData = ref.watch(_analyticsProvider(period));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Analytics',
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
        onRefresh: () async =>
            ref.invalidate(_analyticsProvider(period)),
        child: CustomScrollView(
          slivers: [
            // Period filter chips
            SliverToBoxAdapter(
              child: _PeriodFilterRow(selected: period),
            ),

            // Body
            asyncData.when(
              loading: () => const SliverFillRemaining(
                child: ShimmerKpiGrid(crossAxisCount: 2),
              ),
              error: (e, _) => SliverFillRemaining(
                child: ErrorView(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(_analyticsProvider(period)),
                ),
              ),
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  // KPI grid
                  _KpiGrid(data: data),
                  const SizedBox(height: 8),

                  // Top clients section
                  _TopClientsSection(data: data),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period filter row
// ---------------------------------------------------------------------------

class _PeriodFilterRow extends ConsumerWidget {
  final String selected;

  const _PeriodFilterRow({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const periods = [
      ('7d', '7 Days'),
      ('30d', '30 Days'),
      ('90d', '90 Days'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: periods.map((p) {
          final isSelected = selected == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(_selectedPeriodProvider.notifier).state = p.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryFg
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI grid
// ---------------------------------------------------------------------------

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> data;

  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalRevenue =
        (data['total_revenue'] as num?)?.toDouble() ?? 0;
    final activeClients = data['active_clients'] as int? ?? 0;
    final newSignups = data['new_signups'] as int? ?? 0;
    final commissionEarned =
        (data['commission_earned'] as num?)?.toDouble() ?? 0;

    final kpis = [
      _KpiItem(
        label: 'Total Revenue',
        value: CurrencyFormatter.format(totalRevenue),
        icon: Icons.trending_up_rounded,
        color: AppColors.primary,
      ),
      _KpiItem(
        label: 'Active Clients',
        value: activeClients.toString(),
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      ),
      _KpiItem(
        label: 'New Signups',
        value: newSignups.toString(),
        icon: Icons.person_add_outlined,
        color: AppColors.info,
      ),
      _KpiItem(
        label: 'Commission Earned',
        value: CurrencyFormatter.format(commissionEarned),
        icon: Icons.monetization_on_outlined,
        color: AppColors.secondary,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final cols = constraints.maxWidth > 500 ? 4 : 2;
          final itemWidth =
              (constraints.maxWidth - (cols - 1) * 12) / cols;
          final itemHeight = itemWidth / 1.6;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kpis.map((k) {
              return SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _KpiCard(item: k),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;

  const _KpiCard({required this.item});

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
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  item.label,
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
          const Spacer(),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: item.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top clients section
// ---------------------------------------------------------------------------

class _TopClientsSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const _TopClientsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawClients =
        data['top_clients'] as List<dynamic>? ?? [];
    final clients = rawClients.cast<Map<String, dynamic>>();

    if (clients.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: const Text(
            'TOP PERFORMING CLIENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),

        // Client bars
        ...clients.asMap().entries.map((e) {
          final index = e.key;
          final client = e.value;
          return _TopClientBar(
            rank: index + 1,
            data: client,
            maxRevenue: _maxRevenue(clients),
          );
        }),
      ],
    );
  }

  double _maxRevenue(List<Map<String, dynamic>> clients) {
    if (clients.isEmpty) return 1;
    double max = 0;
    for (final c in clients) {
      final v = (c['revenue'] as num?)?.toDouble() ?? 0;
      if (v > max) max = v;
    }
    return max == 0 ? 1 : max;
  }
}

class _TopClientBar extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final double maxRevenue;

  const _TopClientBar({
    required this.rank,
    required this.data,
    required this.maxRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown';
    final revenue =
        (data['revenue'] as num?)?.toDouble() ?? 0;
    final ratio = (revenue / maxRevenue).clamp(0.0, 1.0);

    final rankColor = rank == 1
        ? AppColors.primary
        : rank == 2
            ? AppColors.textSecondary
            : AppColors.textDisabled;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              // Rank badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: rankColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                CurrencyFormatter.format(revenue),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
