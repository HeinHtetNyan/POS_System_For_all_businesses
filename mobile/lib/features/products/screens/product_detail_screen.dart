import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/products_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/product_model.dart';
import '../../../core/providers/auth_provider.dart';
import 'product_form_screen.dart';

final _productDetailProvider =
    FutureProvider.family<ProductModel, String>((ref, id) async {
  return ref.watch(productsRepositoryProvider).getProduct(id);
});

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(_productDetailProvider(productId));
    final user = ref.watch(currentUserProvider);
    final canEdit = user?.canManageProducts ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: productAsync.whenOrNull(data: (p) => Text(p.name)) ??
            const Text('Product Details'),
        actions: [
          if (canEdit)
            productAsync.whenOrNull(
                  data: (p) => IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(product: p),
                        fullscreenDialog: true,
                      ),
                    ),
                  ),
                ) ??
                const SizedBox(),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.refresh(_productDetailProvider(productId)),
        ),
        data: (product) => ContentWrapper(
          maxWidth: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductHeader(product: product),
                InfoSection(
                  title: 'PRICING',
                  children: [
                    InfoRow(
                        label: 'Selling Price',
                        value: CurrencyFormatter.format(product.sellingPrice),
                        valueColor: AppColors.primary),
                    InfoRow(
                        label: 'Cost Price',
                        value: CurrencyFormatter.format(product.costPrice)),
                    if (product.taxRate > 0)
                      InfoRow(
                          label: 'Tax Rate',
                          value:
                              '${product.taxRate.toStringAsFixed(1)}%'),
                  ],
                ),
                InfoSection(
                  title: 'DETAILS',
                  children: [
                    if (product.sku != null)
                      InfoRow(label: 'SKU', value: product.sku!),
                    if (product.barcode != null)
                      InfoRow(label: 'Barcode', value: product.barcode!),
                    if (product.categoryName != null)
                      InfoRow(
                          label: 'Category', value: product.categoryName!),
                    if (product.unit != null)
                      InfoRow(label: 'Unit', value: product.unit!),
                    InfoRow(label: 'Type', value: product.productType),
                    InfoRow(
                      label: 'Status',
                      value: product.isActive ? 'Active' : 'Inactive',
                      valueColor: product.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ],
                ),
                if (product.quantityOnHand != null)
                  _StockSection(product: product),
                if (product.description != null &&
                    product.description!.isNotEmpty)
                  _DescriptionSection(description: product.description!),
                if (product.hasVariants) _VariantsSection(product: product),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Header

class _ProductHeader extends StatelessWidget {
  final ProductModel product;
  const _ProductHeader({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(product.sellingPrice),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                if (product.categoryName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.categoryName!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          _StatusChip(isActive: product.isActive),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;
  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.error,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Stock

class _StockSection extends StatelessWidget {
  final ProductModel product;
  const _StockSection({required this.product});

  @override
  Widget build(BuildContext context) {
    final qty = product.quantityOnHand!;
    final Color stockColor;
    final Color stockBg;
    final String stockLabel;
    if (qty <= 0) {
      stockColor = AppColors.error;
      stockBg = AppColors.errorLight;
      stockLabel = 'Out of Stock';
    } else if (qty <= (product.reorderPoint > 0 ? product.reorderPoint : 10)) {
      stockColor = AppColors.warning;
      stockBg = AppColors.warningLight;
      stockLabel = 'Low Stock';
    } else {
      stockColor = AppColors.success;
      stockBg = AppColors.successLight;
      stockLabel = 'In Stock';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STOCK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qty.toStringAsFixed(0),
                      style: TextStyle(
                          color: stockColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'units on hand',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: stockBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stockLabel,
                  style: TextStyle(
                      color: stockColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Description

class _DescriptionSection extends StatelessWidget {
  final String description;
  const _DescriptionSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// Variants

class _VariantsSection extends StatelessWidget {
  final ProductModel product;
  const _VariantsSection({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'VARIANTS (${product.variants.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...product.variants.map(
          (v) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      if (v.sku != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${v.sku}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(v.sellingPrice),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: v.isActive ? 'ACTIVE' : 'INACTIVE'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
