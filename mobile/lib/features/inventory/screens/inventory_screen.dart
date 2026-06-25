import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../data/inventory_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../models/user_model.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState
    extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _sortLowFirst = false;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(inventoryProvider.notifier).load();
      await _loadBranches();
    });
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadBranches() async {
    final user = ref.read(currentUserProvider);
    // Only business owners and managers have multi-branch visibility
    if (user == null || !user.isTenantAdmin) return;
    final tenantId = user.tenantId;
    if (tenantId == null || tenantId.isEmpty) return;
    try {
      final response =
          await apiClient.get(ApiEndpoints.branches(tenantId));
      final data = response.data;
      final rawItems = data is Map<String, dynamic>
          ? (data['items'] as List<dynamic>? ??
              data['branches'] as List<dynamic>? ??
              [])
          : (data as List<dynamic>? ?? []);
      final branches = rawItems
          .map((e) => e as Map<String, dynamic>)
          .where((e) =>
              (e['status'] as String? ?? 'ACTIVE') == 'ACTIVE' &&
              (e['id'] as String? ?? '').isNotEmpty)
          .toList();
      if (mounted) setState(() => _branches = branches);
    } catch (_) {
      // Silently fail — branch selector simply stays hidden
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(inventoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final user = ref.watch(currentUserProvider);
    final canAdjust = user?.canManageProducts ?? false;
    final lowStockCount =
        state.items.where((s) => s.isLowStock).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Inventory',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (lowStockCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                avatar: const Icon(
                    Icons.warning_amber_outlined,
                    size: 14,
                    color: AppColors.warning),
                label: Text('$lowStockCount low',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning)),
                backgroundColor: AppColors.warningLight,
                side: BorderSide(
                    color: AppColors.warning
                        .withValues(alpha: 0.3)),
              ),
            ),
          IconButton(
            tooltip: _sortLowFirst ? 'Sorted: Low first' : 'Sort by quantity (current page only)',
            icon: Icon(
              _sortLowFirst ? Icons.arrow_upward : Icons.sort,
              color: _sortLowFirst
                  ? AppColors.primary
                  : AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _sortLowFirst = !_sortLowFirst),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
              _branches.length > 1 ? 140 : 100),
          child: Container(
            color: AppColors.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                        color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by product name...',
                      hintStyle: const TextStyle(
                          color: AppColors.textDisabled),
                      prefixIcon: const Icon(Icons.search,
                          size: 20,
                          color: AppColors.textSecondary),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                      Icons.clear,
                                      size: 18,
                                      color: AppColors
                                          .textSecondary),
                                  onPressed: () {
                                    _searchController
                                        .clear();
                                    ref
                                        .read(inventoryProvider
                                            .notifier)
                                        .search('');
                                  },
                                )
                              : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              vertical: 10),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.primary),
                      ),
                    ),
                    onChanged: (v) => ref
                        .read(inventoryProvider.notifier)
                        .search(v),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: _FilterPill(
                          label: 'All Stock',
                          selected: !state.lowStockOnly,
                          onSelected: (_) => ref
                              .read(
                                  inventoryProvider.notifier)
                              .load(
                                  refresh: true,
                                  lowStockOnly: false),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: _FilterPill(
                          label: 'Low Stock',
                          selected: state.lowStockOnly,
                          icon: Icons.warning_amber_outlined,
                          onSelected: (_) => ref
                              .read(
                                  inventoryProvider.notifier)
                              .toggleLowStockFilter(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Branch selector — only shown when user has multiple branches
                if (_branches.length > 1)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 8),
                          child: _FilterPill(
                            label: 'All Branches',
                            selected: state.branchId == null,
                            onSelected: (_) => ref
                                .read(inventoryProvider.notifier)
                                .selectBranch(null),
                          ),
                        ),
                        ..._branches.map((b) {
                          final id = b['id'] as String;
                          final name =
                              b['name'] as String? ?? 'Branch';
                          return Padding(
                            padding: const EdgeInsets.only(
                                right: 8),
                            child: _FilterPill(
                              label: name,
                              selected: state.branchId == id,
                              icon: Icons.store_outlined,
                              onSelected: (_) => ref
                                  .read(inventoryProvider
                                      .notifier)
                                  .selectBranch(id),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref
            .read(inventoryProvider.notifier)
            .load(refresh: true),
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => ref
                        .read(inventoryProvider.notifier)
                        .load(refresh: true),
                  )
                : state.items.isEmpty
                    ? const EmptyView(
                        icon: Icons.warehouse_outlined,
                        title: 'No stock data found',
                        subtitle:
                            'Stock levels appear after products are created',
                      )
                    : Builder(builder: (_) {
                        final displayItems =
                            List<StockLevelModel>.from(
                                state.items);
                        if (_sortLowFirst) {
                          displayItems.sort((a, b) =>
                              a.quantityOnHand
                                  .compareTo(b.quantityOnHand));
                        }
                        return ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.only(bottom: 80),
                          itemCount: displayItems.length +
                              (state.isLoadingMore ? 1 : 0) +
                              1, // +1 for stats header
                          itemBuilder: (_, i) {
                            // First item: stats grid
                            if (i == 0) {
                              return _InventoryStats(
                                  items: state.items);
                            }
                            final dataIndex = i - 1;
                            if (dataIndex >=
                                displayItems.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child:
                                      CircularProgressIndicator(
                                          color:
                                              AppColors.primary),
                                ),
                              );
                            }
                            return _StockTile(
                              stock: displayItems[dataIndex],
                              canAdjust: canAdjust,
                              onAdjust: canAdjust
                                  ? () => _showAdjustSheet(
                                      context,
                                      displayItems[dataIndex],
                                      user)
                                  : null,
                              onHistory: () =>
                                  _showHistorySheet(
                                      context,
                                      displayItems[dataIndex]),
                            );
                          },
                        );
                      }),
      ),
    );
  }

  void _showHistorySheet(BuildContext context, StockLevelModel stock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints: Responsive.bottomSheetConstraints(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StockHistorySheet(stock: stock),
    );
  }

  void _showAdjustSheet(BuildContext context,
      StockLevelModel stock, UserModel? user) {
    final selectedBranchId = ref.read(inventoryProvider).branchId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      constraints:
          Responsive.bottomSheetConstraints(context),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AdjustStockSheet(
        stock: stock,
        branchId: selectedBranchId ?? user?.primaryBranchId ?? '',
        onSuccess: () => ref
            .read(inventoryProvider.notifier)
            .load(refresh: true),
      ),
    );
  }
}

// Inventory Stats

class _InventoryStats extends StatelessWidget {
  final List<StockLevelModel> items;

  const _InventoryStats({required this.items});

  @override
  Widget build(BuildContext context) {
    final totalItems = items.length;
    final outOfStock =
        items.where((s) => s.quantityOnHand == 0).length;
    final lowStock = items
        .where((s) =>
            s.quantityOnHand > 0 &&
            s.reorderPoint != null &&
            s.quantityOnHand <= s.reorderPoint!)
        .length;
    final totalUnits = items.fold<double>(
        0, (sum, s) => sum + s.quantityOnHand);

    final isWide = MediaQuery.of(context).size.width > 600;

    final cards = [
      _StatCard(
        label: 'Total Items',
        value: '$totalItems',
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.textSecondary,
        iconBg: AppColors.surfaceVariant,
        valueColor: AppColors.textPrimary,
      ),
      _StatCard(
        label: 'Out of Stock',
        value: '$outOfStock',
        icon: Icons.remove_circle_outline,
        iconColor: AppColors.error,
        iconBg: AppColors.errorLight,
        valueColor: AppColors.error,
      ),
      _StatCard(
        label: 'Low Stock',
        value: '$lowStock',
        icon: Icons.warning_amber_outlined,
        iconColor: AppColors.warning,
        iconBg: AppColors.warningLight,
        valueColor: AppColors.warning,
      ),
      _StatCard(
        label: 'Total Units',
        value: totalUnits.toStringAsFixed(0),
        icon: Icons.stacked_bar_chart_outlined,
        iconColor: AppColors.info,
        iconBg: AppColors.infoLight,
        valueColor: AppColors.info,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: isWide
          ? Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          child: c,
                        ),
                      ))
                  .toList(),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 6, bottom: 8),
                        child: cards[0],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.only(left: 6, bottom: 8),
                        child: cards[1],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: cards[2],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: cards[3],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Filter pill

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final ValueChanged<bool> onSelected;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected
              ? AppColors.primaryFg
              : AppColors.textSecondary,
          fontWeight: selected
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
      avatar: icon != null
          ? Icon(icon,
              size: 14,
              color: selected
                  ? AppColors.primaryFg
                  : AppColors.textSecondary)
          : null,
      selected: selected,
      onSelected: onSelected,
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      checkmarkColor: AppColors.primaryFg,
      showCheckmark: false,
      side: BorderSide(
        color:
            selected ? AppColors.primary : AppColors.divider,
      ),
    );
  }
}

// Stock tile

class _StockTile extends StatelessWidget {
  final StockLevelModel stock;
  final bool canAdjust;
  final VoidCallback? onAdjust;
  final VoidCallback? onHistory;

  const _StockTile({
    required this.stock,
    required this.canAdjust,
    this.onAdjust,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final qty = stock.quantityOnHand;
    final isLow = stock.isLowStock;
    final isOut = qty <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Stock-level icon badge
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOut
                  ? AppColors.errorLight
                  : isLow
                      ? AppColors.warningLight
                      : AppColors.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOut
                  ? Icons.remove_circle_outline
                  : isLow
                      ? Icons.warning_amber_outlined
                      : Icons.check_circle_outline,
              color: isOut
                  ? AppColors.error
                  : isLow
                      ? AppColors.warning
                      : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stock.sku != null)
                  Text('SKU: ${stock.sku}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                // Stock status badge
                _StockBadge(isOut: isOut, isLow: isLow),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qty.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isOut
                      ? AppColors.error
                      : isLow
                          ? AppColors.warning
                          : AppColors.textPrimary,
                ),
              ),
              if (stock.reorderPoint != null)
                Text(
                  'Min: ${stock.reorderPoint!.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.history_outlined,
                size: 18,
                color: AppColors.textSecondary),
            tooltip: 'Stock History',
            onPressed: onHistory,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
                minWidth: 36, minHeight: 36),
          ),
          if (canAdjust)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary),
              tooltip: 'Adjust Stock',
              onPressed: onAdjust,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final bool isOut;
  final bool isLow;

  const _StockBadge({required this.isOut, required this.isLow});

  @override
  Widget build(BuildContext context) {
    if (isOut) {
      return _badge(
          label: 'Out of Stock',
          color: AppColors.error,
          bg: AppColors.errorLight);
    }
    if (isLow) {
      return _badge(
          label: 'Low Stock',
          color: AppColors.warning,
          bg: AppColors.warningLight);
    }
    return _badge(
        label: 'In Stock',
        color: AppColors.success,
        bg: AppColors.successLight);
  }

  Widget _badge(
      {required String label,
      required Color color,
      required Color bg}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// Stock History Sheet

class _StockHistorySheet extends ConsumerStatefulWidget {
  final StockLevelModel stock;

  const _StockHistorySheet({required this.stock});

  @override
  ConsumerState<_StockHistorySheet> createState() =>
      _StockHistorySheetState();
}

class _StockHistorySheetState
    extends ConsumerState<_StockHistorySheet> {
  List<StockMovementModel> _movements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ref.read(inventoryRepositoryProvider).getMovements(
        productId: widget.stock.productId,
        branchId: widget.stock.branchId,
      );
      if (mounted) setState(() { _movements = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  (Color, Color) _movementColors(String type) {
    switch (type.toUpperCase()) {
      case 'SALE':
      case 'DAMAGE':
      case 'LOSS':
        return (AppColors.error, AppColors.errorLight);
      case 'REFUND':
        return (AppColors.info, AppColors.infoLight);
      case 'REPLACEMENT':
        return (const Color(0xFF8B5CF6), const Color(0xFF1E1030));
      case 'PURCHASE':
      case 'PURCHASE_RECEIPT':
        return (AppColors.success, AppColors.successLight);
      case 'MANUAL_CORRECTION':
      case 'ADJUSTMENT_INCREASE':
      case 'ADJUSTMENT_DECREASE':
        return (AppColors.warning, AppColors.warningLight);
      case 'OPENING_STOCK':
        return (const Color(0xFFA855F7), const Color(0xFF1A0E2E));
      case 'TRANSFER_IN':
        return (const Color(0xFF06B6D4), const Color(0xFF0C1F24));
      case 'TRANSFER_OUT':
      case 'RETURN_TO_SUPPLIER':
        return (const Color(0xFFF97316), const Color(0xFF2A1200));
      default:
        return (AppColors.textSecondary, AppColors.surfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Stock History',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(widget.stock.productName,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Flexible(
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.error)),
                    )
                  : _movements.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No movements recorded',
                                style: TextStyle(
                                    color:
                                        AppColors.textSecondary)),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(
                              16, 8, 16, 24),
                          itemCount: _movements.length,
                          itemBuilder: (_, i) {
                            final m = _movements[i];
                            final (fg, bg) =
                                _movementColors(m.movementType);
                            final isNeg = m.quantity < 0;
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isNeg
                                          ? Icons.remove
                                          : Icons.add,
                                      color: fg,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.movementType
                                              .replaceAll('_', ' '),
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: fg),
                                        ),
                                        if (m.reference != null)
                                          Text(
                                            m.reference!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors
                                                    .textSecondary),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          '${m.createdAt.day.toString().padLeft(2, '0')}/'
                                          '${m.createdAt.month.toString().padLeft(2, '0')}/'
                                          '${m.createdAt.year}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors
                                                  .textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isNeg ? '' : '+'}${m.quantity.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// Adjust Stock Sheet

class _AdjustStockSheet extends ConsumerStatefulWidget {
  final StockLevelModel stock;
  final String branchId;
  final VoidCallback onSuccess;

  const _AdjustStockSheet({
    required this.stock,
    required this.branchId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AdjustStockSheet> createState() =>
      _AdjustStockSheetState();
}

class _AdjustStockSheetState
    extends ConsumerState<_AdjustStockSheet> {
  final _adjustment = TextEditingController();
  String _reason = 'CORRECTION';
  bool _isSaving = false;

  final _reasons = [
    ('CORRECTION', 'Correction'),
    ('PURCHASE', 'Purchase'),
    ('RETURN', 'Return'),
    ('DAMAGE', 'Damage/Loss'),
    ('OTHER', 'Other'),
  ];

  @override
  void dispose() {
    _adjustment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_adjustment.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter a valid number (e.g. 10 or -5)')));
      return;
    }
    if (widget.branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No branch assigned to your account')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(inventoryRepositoryProvider).adjustStock(
            productId: widget.stock.productId,
            branchId: widget.branchId,
            adjustment: amount,
            reason: _reason,
          );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.stock.quantityOnHand;
    final delta =
        double.tryParse(_adjustment.text) ?? 0;
    final newQty = current + delta;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.stock.productName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary),
                  onPressed: () =>
                      Navigator.of(context).pop()),
            ],
          ),
          Text(
              'Current: ${current.toStringAsFixed(0)} units',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13)),
          const SizedBox(height: 20),
          TextField(
            controller: _adjustment,
            style: const TextStyle(
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Adjustment (e.g. +10 or -5)',
              hintText: '10',
              labelStyle: const TextStyle(
                  color: AppColors.textSecondary),
              hintStyle: const TextStyle(
                  color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.swap_vert,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primary),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(
                signed: true, decimal: true),
            onChanged: (_) => setState(() {}),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          // Reason dropdown
          DropdownButtonFormField<String>(
            initialValue: _reason,
            dropdownColor: AppColors.surfaceVariant,
            style: const TextStyle(
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Reason',
              labelStyle: const TextStyle(
                  color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.info_outline,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primary),
              ),
            ),
            items: _reasons
                .map((r) => DropdownMenuItem(
                    value: r.$1,
                    child: Text(r.$2,
                        style: const TextStyle(
                            color: AppColors.textPrimary))))
                .toList(),
            onChanged: (v) => setState(
                () => _reason = v ?? 'CORRECTION'),
          ),
          const SizedBox(height: 12),
          // Preview
          if (_adjustment.text.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: newQty >= 0
                    ? AppColors.successLight
                    : AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: newQty >= 0
                      ? AppColors.success
                          .withValues(alpha: 0.3)
                      : AppColors.error
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Quantity',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  Text(
                    newQty.toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: newQty >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryFg),
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const CircularProgressIndicator(
                      color: AppColors.primaryFg)
                  : const Text('Apply Adjustment',
                      style: TextStyle(
                          fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
