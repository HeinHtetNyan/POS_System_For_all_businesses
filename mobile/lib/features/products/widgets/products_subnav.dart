import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class ProductsSubnav extends StatelessWidget {
  final String current;

  const ProductsSubnav({
    super.key,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _TabButton(
              label: 'Products',
              active: current == 'products',
              onTap: current == 'products' ? null : () => context.go('/products'),
            ),
            _TabButton(
              label: 'Categories',
              active: current == 'categories',
              onTap: current == 'categories' ? null : () => context.go('/categories'),
            ),
            _TabButton(
              label: 'Brands',
              active: current == 'brands',
              onTap: current == 'brands' ? null : () => context.go('/brands'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: active ? AppColors.primary : AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: const RoundedRectangleBorder(),
      ),
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
