import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/reseller_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _InventoryState {
  final List<Map<String, dynamic>> businesses;
  final String? selectedBusinessId;
  final List<Map<String, dynamic>> items;
  final bool isLoadingBusinesses;
  final bool isLoadingInventory;
  final String? error;
  final String searchQuery;

  const _InventoryState({
    this.businesses = const [],
    this.selectedBusinessId,
    this.items = const [],
    this.isLoadingBusinesses = false,
    this.isLoadingInventory = false,
    this.error,
    this.searchQuery = '',
  });

  _InventoryState copyWith({
    List<Map<String, dynamic>>? businesses,
    String? selectedBusinessId,
    List<Map<String, dynamic>>? items,
    bool? isLoadingBusinesses,
    bool? isLoadingInventory,
    String? error,
    String? searchQuery,
    bool clearError = false,
    bool clearSelectedBusiness = false,
  }) =>
      _InventoryState(
        businesses: businesses ?? this.businesses,
        selectedBusinessId: clearSelectedBusiness
            ? null
            : (selectedBusinessId ?? this.selectedBusinessId),
        items: items ?? this.items,
        isLoadingBusinesses: isLoadingBusinesses ?? this.isLoadingBusinesses,
        isLoadingInventory: isLoadingInventory ?? this.isLoadingInventory,
        error: clearError ? null : (error ?? this.error),
        searchQuery: searchQuery ?? this.searchQuery,
      );

  List<Map<String, dynamic>> get filteredItems {
    if (searchQuery.isEmpty) return items;
    final q = searchQuery.toLowerCase();
    return items.where((item) {
      final name =
          (item['product_name'] as String? ?? item['name'] as String? ?? '')
              .toLowerCase();
      return name.contains(q);
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _InventoryNotifier extends StateNotifier<_InventoryState> {
  final ResellerRepository _repo;

  _InventoryNotifier(this._repo) : super(const _InventoryState());

  Future<void> init() async {
    state = state.copyWith(isLoadingBusinesses: true, clearError: true);
    try {
      final businesses = await _repo.getManagedBusinesses();
      state = state.copyWith(
        businesses: businesses,
        isLoadingBusinesses: false,
      );
      await _loadInventory();
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
    await _loadInventory();
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    await _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (state.businesses.isEmpty) return;
    final tenantId =
        state.selectedBusinessId ?? state.businesses.first['id']?.toString();
    if (tenantId == null) return;

    state = state.copyWith(isLoadingInventory: true, clearError: true);
    try {
      final r = await apiClient.dio.get(
        '/inventory/stock-levels',
        queryParameters: {'tenant_id': tenantId, 'page_size': 100},
      );
      final data = r.data as Map<String, dynamic>;
      final raw = (data['items'] as List<dynamic>?) ??
          (r.data is List ? r.data as List<dynamic> : []);
      state = state.copyWith(
        items: raw.cast<Map<String, dynamic>>(),
        isLoadingInventory: false,
      );
    } catch (e) {
      state =
          state.copyWith(isLoadingInventory: false, error: e.toString());
    }
  }

  void setSearch(String q) {
    state = state.copyWith(searchQuery: q);
  }
}

final _inventoryProvider =
    StateNotifierProvider.autoDispose<_InventoryNotifier, _InventoryState>(
  (ref) => _InventoryNotifier(ref.watch(resellerRepositoryProvider)),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerInventoryScreen extends ConsumerStatefulWidget {
  const ResellerInventoryScreen({super.key});

  @override
  ConsumerState<ResellerInventoryScreen> createState() =>
      _ResellerInventoryScreenState();
}

class _ResellerInventoryScreenState
    extends ConsumerState<ResellerInventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(_inventoryProvider.notifier).init());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_inventoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Inventory',
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
          ? const ShimmerList(itemCount: 8, itemHeight: 76)
          : state.error != null && state.items.isEmpty
              ? ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(_inventoryProvider.notifier).init(),
                )
              : Column(
                  children: [
                    _BusinessDropdown(state: state),
                    _SearchBar(
                        controller: _searchController, state: state),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            ref.read(_inventoryProvider.notifier).refresh(),
                        child: state.isLoadingInventory
                            ? const ShimmerList(itemCount: 8, itemHeight: 76)
                            : state.filteredItems.isEmpty
                                ? const EmptyView(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'No Inventory Data',
                                    subtitle:
                                        'No stock levels found for this business.',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    itemCount: state.filteredItems.length,
                                    itemBuilder: (context, index) =>
                                        _InventoryCard(
                                            data:
                                                state.filteredItems[index]),
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
  final _InventoryState state;

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
              ref.read(_inventoryProvider.notifier).selectBusiness(id),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends ConsumerWidget {
  final TextEditingController controller;
  final _InventoryState state;

  const _SearchBar({required this.controller, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by product name...',
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textSecondary, size: 20),
          suffixIcon: state.searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    ref.read(_inventoryProvider.notifier).setSearch('');
                  },
                  child: const Icon(Icons.close,
                      color: AppColors.textSecondary, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        onChanged: (q) =>
            ref.read(_inventoryProvider.notifier).setSearch(q),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock status helpers
// ---------------------------------------------------------------------------

enum _StockStatus { inStock, low, outOfStock }

_StockStatus _resolveStatus(Map<String, dynamic> data) {
  final current = (data['current_stock'] as num?)?.toInt() ??
      (data['quantity_on_hand'] as num?)?.toInt() ?? 0;
  final reorderPoint = (data['reorder_point'] as num?)?.toInt() ?? 0;
  if (current <= 0) return _StockStatus.outOfStock;
  if (current <= reorderPoint) return _StockStatus.low;
  return _StockStatus.inStock;
}

Color _statusColor(_StockStatus status) {
  switch (status) {
    case _StockStatus.inStock:
      return AppColors.success;
    case _StockStatus.low:
      return AppColors.warning;
    case _StockStatus.outOfStock:
      return AppColors.error;
  }
}

Color _statusBgColor(_StockStatus status) {
  switch (status) {
    case _StockStatus.inStock:
      return AppColors.successLight;
    case _StockStatus.low:
      return AppColors.warningLight;
    case _StockStatus.outOfStock:
      return AppColors.errorLight;
  }
}

String _statusLabel(_StockStatus status) {
  switch (status) {
    case _StockStatus.inStock:
      return 'In Stock';
    case _StockStatus.low:
      return 'Low';
    case _StockStatus.outOfStock:
      return 'Out';
  }
}

// ---------------------------------------------------------------------------
// Inventory card
// ---------------------------------------------------------------------------

class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _InventoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final productName = data['product_name'] as String? ??
        data['name'] as String? ?? 'Unknown Product';
    final sku = data['sku'] as String?;
    final currentStock = (data['current_stock'] as num?)?.toInt() ??
        (data['quantity_on_hand'] as num?)?.toInt() ?? 0;
    final reorderPoint =
        (data['reorder_point'] as num?)?.toInt() ?? 0;
    final status = _resolveStatus(data);
    final statusColor = _statusColor(status);
    final statusBg = _statusBgColor(status);
    final statusText = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sku != null && sku.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'SKU: $sku',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Stock: $currentStock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      if (reorderPoint > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Reorder: $reorderPoint',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
