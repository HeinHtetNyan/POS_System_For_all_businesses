import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/products_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../models/product_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/hardware/printer_service.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import '../widgets/products_subnav.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(productsProvider.notifier).load();
      await ref.read(productsProvider.notifier).loadCategories();
    });
    _scrollController.addListener(_onScroll);
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
      ref.read(productsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final user = ref.watch(currentUserProvider);
    final canCreate = user?.canManageProducts ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(144),
          child: Column(
            children: [
              const ProductsSubnav(current: 'products'),
              Container(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(productsProvider.notifier).search('');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    ref.read(productsProvider.notifier).search(v);
                  },
                ),
              ),
              if (state.categories.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.categories.length + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        final selected = state.categoryFilter == null;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: 'All',
                            selected: selected,
                            onSelected: (_) => ref
                                .read(productsProvider.notifier)
                                .filterCategory(null),
                          ),
                        );
                      }
                      final cat = state.categories[i - 1];
                      final selected = state.categoryFilter == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: cat.name,
                          selected: selected,
                          onSelected: (_) => ref
                              .read(productsProvider.notifier)
                              .filterCategory(cat.id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryFg,
              onPressed: () => _showForm(context, null),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(productsProvider.notifier).load(refresh: true),
        child: state.isLoading
            ? const ShimmerList(itemHeight: 76)
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => ref.read(productsProvider.notifier).load(refresh: true),
                  )
                : state.items.isEmpty
                    ? EmptyView(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products found',
                        action: canCreate
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.primaryFg,
                                ),
                                onPressed: () => _showForm(context, null),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Product'),
                              )
                            : null,
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i >= state.items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }
                              return _ProductTile(
                                product: state.items[i],
                                canEdit: canCreate,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                        productId: state.items[i].id),
                                  ),
                                ),
                                onEdit: canCreate
                                    ? () => _showForm(context, state.items[i])
                                    : null,
                                onPrintLabel: () =>
                                    _printLabel(context, state.items[i]),
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }

  void _showForm(BuildContext context, ProductModel? product) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductFormScreen(product: product),
      fullscreenDialog: true,
    ));
  }

  Future<void> _printLabel(
      BuildContext context, ProductModel product) async {
    final ok = await printerService.printLabel(product);
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Label sent to printer'
          : 'No printer connected — set up in Settings > Printer'),
      backgroundColor: ok ? AppColors.success : AppColors.warning,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// Reusable dark filter chip
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primaryFg : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Product tile
class _ProductTile extends StatelessWidget {
  final ProductModel product;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onPrintLabel;

  const _ProductTile({
    required this.product,
    required this.canEdit,
    this.onTap,
    this.onEdit,
    this.onPrintLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 48, height: 48,
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.textSecondary),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.textSecondary),
                        ),
                      )
                    : Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 22, color: AppColors.textSecondary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (product.discountType != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PROMO',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        _StatusBadge(
                          label: product.isActive ? 'ACTIVE' : 'INACTIVE',
                          bg: product.isActive
                              ? AppColors.successLight
                              : AppColors.surfaceVariant,
                          fg: product.isActive
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (product.sku != null)
                          Text(
                            'SKU: ${product.sku}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        if (product.categoryName != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              product.categoryName!,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.info),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.sellingPrice),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        if (product.quantityOnHand != null)
                          Text(
                            'Stock: ${product.quantityOnHand!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: (product.quantityOnHand ?? 0) > 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.textSecondary),
                color: AppColors.surfaceVariant,
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'label') onPrintLabel?.call();
                },
                itemBuilder: (_) => [
                  if (canEdit)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Text('Edit',
                            style: TextStyle(color: AppColors.textPrimary)),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'label',
                    child: Row(children: [
                      Icon(Icons.print_outlined,
                          size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 10),
                      Text('Print Label',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Inline status badge
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _StatusBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
