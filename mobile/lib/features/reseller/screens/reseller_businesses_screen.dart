import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/reseller_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _BusinessesState {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;

  const _BusinessesState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
  });

  _BusinessesState copyWith({
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? page,
    bool clearError = false,
  }) =>
      _BusinessesState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _BusinessesNotifier extends StateNotifier<_BusinessesState> {
  final ResellerRepository _repo;

  _BusinessesNotifier(this._repo) : super(const _BusinessesState());

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = const _BusinessesState(isLoading: true);
    }
    try {
      final items = await _repo.getBusinesses(page: 1);
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: items.length >= 20,
        page: 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = await _repo.getBusinesses(page: state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...next],
        isLoadingMore: false,
        hasMore: next.length >= 20,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final _businessesProvider =
    StateNotifierProvider.autoDispose<_BusinessesNotifier, _BusinessesState>(
  (ref) => _BusinessesNotifier(ref.watch(resellerRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerBusinessesScreen extends ConsumerStatefulWidget {
  const ResellerBusinessesScreen({super.key});

  @override
  ConsumerState<ResellerBusinessesScreen> createState() =>
      _ResellerBusinessesScreenState();
}

class _ResellerBusinessesScreenState
    extends ConsumerState<ResellerBusinessesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(_businessesProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(_businessesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_businessesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'My Clients',
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
            ref.read(_businessesProvider.notifier).load(refresh: true),
        child: state.isLoading
            ? const ShimmerList(itemCount: 8, itemHeight: 80)
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(_businessesProvider.notifier).load(refresh: true),
                  )
                : state.items.isEmpty
                    ? const EmptyView(
                        icon: Icons.business_outlined,
                        title: 'No Clients Yet',
                        subtitle:
                            'Businesses you refer will appear here.',
                      )
                    : CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // Total count banner
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.business_outlined,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Clients: ${state.items.length}${state.hasMore ? '+' : ''}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // List
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index == state.items.length) {
                                    return state.isLoadingMore
                                        ? const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                  color: AppColors.primary,
                                                  strokeWidth: 2),
                                            ),
                                          )
                                        : const SizedBox.shrink();
                                  }
                                  return _BusinessCard(
                                      data: state.items[index]);
                                },
                                childCount: state.items.length + 1,
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business card
// ---------------------------------------------------------------------------

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _BusinessCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Unknown Business';
    final plan = data['plan_name'] as String? ?? '-';
    final status = data['status'] as String? ?? 'unknown';
    final joinedRaw = data['created_at'] as String?;
    final joined = _formatDate(joinedRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(
              '/reseller/businesses/${data['tenant_id'] ?? data['id'] ?? ''}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_outlined,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.card_membership_outlined,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            plan,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (joined != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 11, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Joined $joined',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status badge
                StatusBadge(status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _formatDate(String? raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }
}
