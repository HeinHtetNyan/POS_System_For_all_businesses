import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reseller_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kStatusAll = 'ALL';
const _kStatusFilters = [
  _kStatusAll,
  'DRAFT',
  'PENDING',
  'CONFIRMED',
  'RECEIVED',
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _ProcurementState {
  final List<Map<String, dynamic>> businesses;
  final String? selectedBusinessId;
  final List<Map<String, dynamic>> orders;
  final bool isLoadingBusinesses;
  final bool isLoadingOrders;
  final String? error;
  final String statusFilter;

  const _ProcurementState({
    this.businesses = const [],
    this.selectedBusinessId,
    this.orders = const [],
    this.isLoadingBusinesses = false,
    this.isLoadingOrders = false,
    this.error,
    this.statusFilter = _kStatusAll,
  });

  _ProcurementState copyWith({
    List<Map<String, dynamic>>? businesses,
    String? selectedBusinessId,
    List<Map<String, dynamic>>? orders,
    bool? isLoadingBusinesses,
    bool? isLoadingOrders,
    String? error,
    String? statusFilter,
    bool clearError = false,
    bool clearSelectedBusiness = false,
  }) =>
      _ProcurementState(
        businesses: businesses ?? this.businesses,
        selectedBusinessId: clearSelectedBusiness
            ? null
            : (selectedBusinessId ?? this.selectedBusinessId),
        orders: orders ?? this.orders,
        isLoadingBusinesses: isLoadingBusinesses ?? this.isLoadingBusinesses,
        isLoadingOrders: isLoadingOrders ?? this.isLoadingOrders,
        error: clearError ? null : (error ?? this.error),
        statusFilter: statusFilter ?? this.statusFilter,
      );

  List<Map<String, dynamic>> get filteredOrders {
    if (statusFilter == _kStatusAll) return orders;
    return orders.where((o) {
      final s = (o['status'] as String? ?? '').toUpperCase();
      return s == statusFilter;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _ProcurementNotifier extends StateNotifier<_ProcurementState> {
  final ResellerRepository _repo;

  _ProcurementNotifier(this._repo) : super(const _ProcurementState());

  Future<void> init() async {
    state = state.copyWith(isLoadingBusinesses: true, clearError: true);
    try {
      final businesses = await _repo.getManagedBusinesses();
      state = state.copyWith(
        businesses: businesses,
        isLoadingBusinesses: false,
      );
      await _loadOrders();
    } catch (e) {
      state = state.copyWith(
        isLoadingBusinesses: false,
        error: e.toString(),
      );
    }
  }

  Future<void> selectBusiness(String? businessId) async {
    state = state.copyWith(
      selectedBusinessId: businessId,
      clearSelectedBusiness: businessId == null,
    );
    await _loadOrders();
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    await _loadOrders();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<void> _loadOrders() async {
    if (state.businesses.isEmpty) return;
    final tenantId =
        state.selectedBusinessId ?? state.businesses.first['id']?.toString();
    if (tenantId == null) return;

    state = state.copyWith(isLoadingOrders: true, clearError: true);
    try {
      final r = await apiClient.dio.get(
        '/procurement/purchase-orders',
        queryParameters: {'tenant_id': tenantId, 'page_size': 100},
      );
      final data = r.data as Map<String, dynamic>;
      final raw = (data['items'] as List<dynamic>?) ??
          (r.data is List ? r.data as List<dynamic> : []);
      state = state.copyWith(
        orders: raw.cast<Map<String, dynamic>>(),
        isLoadingOrders: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingOrders: false, error: e.toString());
    }
  }
}

final _procurementProvider =
    StateNotifierProvider.autoDispose<_ProcurementNotifier, _ProcurementState>(
  (ref) => _ProcurementNotifier(ref.watch(resellerRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerProcurementScreen extends ConsumerStatefulWidget {
  const ResellerProcurementScreen({super.key});

  @override
  ConsumerState<ResellerProcurementScreen> createState() =>
      _ResellerProcurementScreenState();
}

class _ResellerProcurementScreenState
    extends ConsumerState<ResellerProcurementScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_procurementProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_procurementProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Purchase Orders',
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
      body: state.isLoadingBusinesses
          ? const ShimmerList(itemCount: 8, itemHeight: 88)
          : state.error != null && state.orders.isEmpty
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(_procurementProvider.notifier).init(),
                )
              : Column(
                  children: [
                    _BusinessDropdown(state: state),
                    _StatusFilterRow(state: state),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            ref.read(_procurementProvider.notifier).refresh(),
                        child: state.isLoadingOrders
                            ? const ShimmerList(itemCount: 8, itemHeight: 88)
                            : state.filteredOrders.isEmpty
                                ? const EmptyView(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'No Purchase Orders',
                                    subtitle:
                                        'No purchase orders found for this business or filter.',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    itemCount: state.filteredOrders.length,
                                    itemBuilder: (context, index) =>
                                        _PurchaseOrderCard(
                                            data:
                                                state.filteredOrders[index]),
                                  ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business dropdown
// ---------------------------------------------------------------------------

class _BusinessDropdown extends ConsumerWidget {
  final _ProcurementState state;

  const _BusinessDropdown({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <DropdownMenuItem<String?>>[
      ...state.businesses.map((b) {
        final id = b['id']?.toString() ?? '';
        final name = b['name'] as String? ?? 'Unknown';
        return DropdownMenuItem(
          value: id,
          child: Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }),
    ];

    final currentValue = state.selectedBusinessId ??
        (state.businesses.isNotEmpty
            ? state.businesses.first['id']?.toString()
            : null);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: currentValue,
          isExpanded: true,
          dropdownColor: AppColors.surfaceVariant,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textSecondary, size: 20),
          items: items,
          onChanged: (id) =>
              ref.read(_procurementProvider.notifier).selectBusiness(id),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status filter row
// ---------------------------------------------------------------------------

class _StatusFilterRow extends ConsumerWidget {
  final _ProcurementState state;

  const _StatusFilterRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: _kStatusFilters.length,
        itemBuilder: (context, index) {
          final filter = _kStatusFilters[index];
          final isSelected = state.statusFilter == filter;
          final label = filter == _kStatusAll
              ? 'All'
              : filter[0] + filter.substring(1).toLowerCase();

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref
                  .read(_procurementProvider.notifier)
                  .setStatusFilter(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
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
                  label,
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
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase order card
// ---------------------------------------------------------------------------

class _PurchaseOrderCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PurchaseOrderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final poNumber = data['po_number'] as String? ??
        data['reference_number'] as String? ?? '#Unknown';
    final supplierName = data['supplier_name'] as String? ??
        (data['supplier'] as Map<String, dynamic>?)?['name'] as String? ??
        'Unknown Supplier';
    final total =
        (data['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = data['status'] as String? ?? 'unknown';
    final createdRaw = data['created_at'] as String?;
    final createdDate = _formatDate(createdRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supplierName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: AppColors.divider,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (createdDate != null)
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        createdDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  CurrencyFormatter.format(total),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
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
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return null;
    }
  }
}
