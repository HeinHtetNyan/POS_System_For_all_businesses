import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/pos_provider.dart';
import '../../../models/product_model.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/utils/currency_formatter.dart';

// lightweight category item for the filter row
class _CategoryItem {
  final String id;
  final String name;
  const _CategoryItem({required this.id, required this.name});
}

final _posCategoriesProvider =
    FutureProvider.autoDispose<List<_CategoryItem>>((_) async {
  try {
    final resp = await apiClient.dio.get(
      ApiEndpoints.categories,
      queryParameters: {'page_size': 100, 'is_active': true},
    );
    final data = resp.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return _CategoryItem(
        id: m['id']?.toString() ?? '',
        name: m['name'] as String? ?? '',
      );
    }).toList();
  } on DioException {
    return [];
  }
});

class ProductGrid extends ConsumerStatefulWidget {
  final String? branchId;
  final String sessionId;
  final String branchIdForCart;
  final VoidCallback? onItemAdded;

  const ProductGrid({
    super.key,
    required this.branchId,
    required this.sessionId,
    required this.branchIdForCart,
    this.onItemAdded,
  });

  @override
  ConsumerState<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<ProductGrid> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productState =
        ref.watch(productListProvider(widget.branchId));
    final cartParams = (
      branchId: widget.branchIdForCart,
      sessionId: widget.sessionId,
    );

    return Column(
      children: [
        // Search bar — surfaceVariant fill, divider border
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search products or scan barcode...',
              hintStyle: const TextStyle(
                  color: AppColors.textDisabled, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 20, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(productListProvider(widget.branchId)
                                .notifier)
                            .search('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (q) {
              ref
                  .read(productListProvider(widget.branchId).notifier)
                  .search(q);
            },
          ),
        ),

        // Category filter chips
        _CategoryFilterRow(branchId: widget.branchId),

        // Product grid
        Expanded(
          child: productState.isLoading && productState.products.isEmpty
              ? LayoutBuilder(
                  builder: (_, c) => ShimmerGrid(
                    crossAxisCount: c.maxWidth > 600 ? 4 : 3,
                  ),
                )
              : productState.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 48, color: AppColors.textDisabled),
                          const SizedBox(height: 12),
                          Text(
                            productState.search.isNotEmpty
                                ? 'No products found for "${productState.search}"'
                                : 'No products available',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceVariant,
                      onRefresh: () => ref
                          .read(productListProvider(widget.branchId)
                              .notifier)
                          .loadProducts(refresh: true),
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final crossAxisCount =
                              constraints.maxWidth > 600 ? 4 : 3;
                          return GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: productState.products.length +
                                (productState.hasMore ? 1 : 0),
                            itemBuilder: (ctx, idx) {
                              if (idx >= productState.products.length) {
                                // Load more trigger
                                WidgetsBinding.instance
                                    .addPostFrameCallback(
                                  (_) => ref
                                      .read(productListProvider(
                                              widget.branchId)
                                          .notifier)
                                      .loadProducts(),
                                );
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                );
                              }
                              final product = productState.products[idx];
                              return _ProductCard(
                                product: product,
                                onTap: () {
                                  if (product.isVariable &&
                                      product.hasVariants) {
                                    _showVariantPicker(
                                        context, product, cartParams);
                                  } else {
                                    ref
                                        .read(posCartProvider(cartParams)
                                            .notifier)
                                        .addItem(product);
                                    widget.onItemAdded?.call();
                                  }
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showVariantPicker(
    BuildContext context,
    ProductModel product,
    ({String branchId, String sessionId}) cartParams,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _VariantPicker(
        product: product,
        onSelect: (variant) {
          ref
              .read(posCartProvider(cartParams).notifier)
              .addItem(product, variant: variant);
          Navigator.pop(ctx);
          widget.onItemAdded?.call();
        },
      ),
    );
  }
}

// Category filter row

class _CategoryFilterRow extends ConsumerWidget {
  final String? branchId;
  const _CategoryFilterRow({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_posCategoriesProvider);
    final productState = ref.watch(productListProvider(branchId));
    final selectedId = productState.categoryId;

    return categoriesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) {
        if (cats.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cats.length + 1, // +1 for "All"
            itemBuilder: (_, i) {
              final isAll = i == 0;
              final catId = isAll ? null : cats[i - 1].id;
              final label = isAll ? 'All' : cats[i - 1].name;
              final isSelected = selectedId == catId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => ref
                      .read(productListProvider(branchId).notifier)
                      .filterByCategory(catId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
      },
    );
  }
}

// Promo badge colours

const _kPromoActiveBg = Color(0xFFF59E0B);   // amber-400
const _kPromoActiveFg = Color(0xFF1C1917);   // near-black — good contrast
const _kPromoScheduledBg = Color(0xFF3B82F6); // blue-500
const _kPromoScheduledFg = Colors.white;

// Product card

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  /// Returns the short badge label for an active promo, e.g. "15% OFF" or
  /// "-500 OFF".
  String _promoLabel() {
    final v = product.discountValue!;
    if (product.discountType == 'PERCENTAGE') {
      // Show integer when whole number, otherwise 1 decimal
      final display = v == v.truncateToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
      return '$display% OFF';
    }
    // AMOUNT
    final display = v == v.truncateToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(0);
    return '-$display OFF';
  }

  @override
  Widget build(BuildContext context) {
    final isPromoActive = product.isPromoActive;
    final isPromoScheduled = !isPromoActive && product.isPromoScheduled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPromoActive
                ? _kPromoActiveBg.withValues(alpha: 0.6)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with optional badge overlay
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Background / image
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.textDisabled,
                                size: 32,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            size: 32,
                            color: AppColors.primary
                                .withValues(alpha: 0.4),
                          ),
                  ),

                  // Active promo badge — top-right corner
                  if (isPromoActive)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _PromoBadge(
                        label: _promoLabel(),
                        bgColor: _kPromoActiveBg,
                        fgColor: _kPromoActiveFg,
                      ),
                    ),

                  // Scheduled promo badge — top-right corner
                  if (isPromoScheduled)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: _PromoBadge(
                        label: 'SOON',
                        bgColor: _kPromoScheduledBg,
                        fgColor: _kPromoScheduledFg,
                      ),
                    ),
                ],
              ),
            ),

            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name — textPrimary, max 2 lines
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),

                    // Price section
                    if (isPromoActive) ...[
                      // Strikethrough original price
                      Text(
                        CurrencyFormatter.format(product.sellingPrice),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textDisabled,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textDisabled,
                        ),
                      ),
                      // Effective discounted price in amber
                      Text(
                        CurrencyFormatter.format(product.effectivePrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kPromoActiveBg,
                        ),
                      ),
                    ] else ...[
                      // Regular price
                      Text(
                        CurrencyFormatter.format(product.sellingPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small reusable promo badge pill

class _PromoBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color fgColor;

  const _PromoBadge({
    required this.label,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fgColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// Variant picker bottom sheet

class _VariantPicker extends StatelessWidget {
  final ProductModel product;
  final void Function(ProductVariantModel) onSelect;

  const _VariantPicker(
      {required this.product, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Select variant for ${product.name}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: product.variants.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (ctx, idx) {
                final v = product.variants[idx];
                return ListTile(
                  title: Text(v.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14)),
                  subtitle: v.attr1Value != null
                      ? Text('${v.attr1Name}: ${v.attr1Value}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12))
                      : null,
                  trailing: Text(
                    CurrencyFormatter.format(v.sellingPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => onSelect(v),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
