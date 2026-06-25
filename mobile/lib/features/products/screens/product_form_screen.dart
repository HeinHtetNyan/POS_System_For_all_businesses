import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../data/products_repository.dart';
import '../providers/products_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/product_model.dart';

class _BrandItem {
  final String id;
  final String name;
  const _BrandItem({required this.id, required this.name});
}

final _brandsProvider = FutureProvider.autoDispose<List<_BrandItem>>((_) async {
  try {
    final resp = await apiClient.dio
        .get(ApiEndpoints.brands, queryParameters: {'page_size': 200});
    final data = resp.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? [];
    return items.map((e) {
      final m = e as Map<String, dynamic>;
      return _BrandItem(id: m['id']?.toString() ?? '', name: m['name'] as String? ?? '');
    }).toList();
  } on DioException {
    return [];
  }
});

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  bool get isEdit => product != null;

  @override
  ConsumerState<ProductFormScreen> createState() =>
      _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _costPrice = TextEditingController();
  final _description = TextEditingController();
  final _reorderPoint = TextEditingController(text: '0');
  final _openingStock = TextEditingController(text: '0');
  final _discountValue = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedBrandId;
  bool _isActive = true;
  bool _isSaving = false;
  bool _hasDiscount = false;
  String _discountType = 'PERCENTAGE'; // PERCENTAGE | AMOUNT
  DateTime? _discountStartAt;
  DateTime? _discountEndAt;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _name.text = p.name;
      _sku.text = p.sku ?? '';
      _barcode.text = p.barcode ?? '';
      _sellingPrice.text = p.sellingPrice.toStringAsFixed(0);
      _costPrice.text = p.costPrice.toStringAsFixed(0);
      _description.text = p.description ?? '';
      _selectedCategoryId = p.categoryId;
      _selectedBrandId = p.brandId;
      _isActive = p.isActive;
      _reorderPoint.text = p.reorderPoint.toString();
      if (p.discountType != null) {
        _hasDiscount = true;
        _discountType = p.discountType!;
        _discountValue.text = p.discountValue?.toStringAsFixed(0) ?? '';
        _discountStartAt = p.discountStartAt;
        _discountEndAt = p.discountEndAt;
      }
    }
    Future.microtask(() {
      if (ref.read(productsProvider).categories.isEmpty) {
        ref.read(productsProvider.notifier).loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _sellingPrice.dispose();
    _costPrice.dispose();
    _description.dispose();
    _reorderPoint.dispose();
    _openingStock.dispose();
    _discountValue.dispose();
    super.dispose();
  }

  Future<void> _openCameraScanner() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BarcodeScannerSheet(),
    );
    if (result != null && mounted) {
      setState(() => _barcode.text = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final rp = int.tryParse(_reorderPoint.text) ?? 0;
      final openingQty = widget.isEdit ? 0 : (int.tryParse(_openingStock.text) ?? 0);
      final data = {
        'name': _name.text.trim(),
        if (_sku.text.trim().isNotEmpty) 'sku': _sku.text.trim(),
        if (_barcode.text.trim().isNotEmpty)
          'barcode': _barcode.text.trim(),
        'selling_price': double.parse(_sellingPrice.text),
        'cost_price': _costPrice.text.isNotEmpty
            ? double.parse(_costPrice.text)
            : 0.0,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
        if (_selectedBrandId != null) 'brand_id': _selectedBrandId,
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'is_active': _isActive,
        'reorder_point': rp,
        if (_hasDiscount && _discountValue.text.trim().isNotEmpty) ...{
          'discount_type': _discountType,
          'discount_value': double.tryParse(_discountValue.text) ?? 0.0,
          if (_discountStartAt != null)
            'discount_start_at': _discountStartAt!.toIso8601String(),
          if (_discountEndAt != null)
            'discount_end_at': _discountEndAt!.toIso8601String(),
        } else if (!_hasDiscount && widget.product?.discountType != null) ...{
          'discount_type': null,
          'discount_value': null,
        },
      };

      if (widget.isEdit) {
        final updated = await repo.updateProduct(widget.product!.id, data);
        ref.read(productsProvider.notifier).updateItem(updated);
      } else {
        final created = await repo.createProduct(data);
        ref.read(productsProvider.notifier).addItem(created);
        if (openingQty > 0) {
          final branchId = ref.read(authProvider).user?.primaryBranchId ?? '';
          if (branchId.isNotEmpty) {
            await apiClient.dio.post(ApiEndpoints.openingStockAdjustment, data: {
              'branch_id': branchId,
              'movement_type': 'OPENING_STOCK',
              'items': [
                {
                  'product_id': created.id,
                  'quantity': openingQty.toString(),
                  'cost_price': _costPrice.text.isNotEmpty ? _costPrice.text : '0',
                }
              ],
            });
          }
        }
      }

      if (mounted) Navigator.of(context).pop();
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
    final categories = ref.watch(productsProvider).categories;
    final brandsAsync = ref.watch(_brandsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Product' : 'New Product'),
      ),
      body: ContentWrapper(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // BASIC INFO section header
              _SectionHeader(label: 'BASIC INFO'),
              const SizedBox(height: 12),

              // Name
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // SKU
              TextFormField(
                controller: _sku,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),

              // Barcode — camera scan button available on all screen sizes
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcode,
                      decoration: const InputDecoration(
                        labelText: 'Barcode',
                        prefixIcon: Icon(Icons.qr_code_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Tooltip(
                      message: 'Scan barcode',
                      child: InkWell(
                        onTap: _openCameraScanner,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_outlined,
                            color: AppColors.primaryFg,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // PRICING section header
              _SectionHeader(label: 'PRICING'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPrice,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price *',
                        prefixText: 'MMK ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costPrice,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        prefixText: 'MMK ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            double.tryParse(v) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              // ADDITIONAL section header
              _SectionHeader(label: 'ADDITIONAL'),
              const SizedBox(height: 12),

              // Category
              if (categories.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  dropdownColor: AppColors.surfaceVariant,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  iconEnabledColor: AppColors.textSecondary,
                  items: [
                    const DropdownMenuItem(
                        value: null,
                        child: Text('No category',
                            style:
                                TextStyle(color: AppColors.textSecondary))),
                    ...categories.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
                const SizedBox(height: 12),
              ],

              // Brand
              brandsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (brands) => brands.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBrandId,
                            decoration: const InputDecoration(
                              labelText: 'Brand',
                              prefixIcon: Icon(Icons.branding_watermark_outlined),
                            ),
                            dropdownColor: AppColors.surfaceVariant,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 14),
                            iconEnabledColor: AppColors.textSecondary,
                            items: [
                              const DropdownMenuItem(
                                  value: null,
                                  child: Text('No brand',
                                      style: TextStyle(color: AppColors.textSecondary))),
                              ...brands.map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _selectedBrandId = v),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
              ),

              // Description
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              // INVENTORY section
              const SizedBox(height: 8),
              _SectionHeader(label: 'INVENTORY'),
              const SizedBox(height: 12),
              if (!widget.isEdit) ...[
                TextFormField(
                  controller: _openingStock,
                  decoration: const InputDecoration(
                    labelText: 'Opening Stock',
                    prefixIcon: Icon(Icons.add_box_outlined),
                    hintText: '0',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                      return 'Must be a whole number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _reorderPoint,
                decoration: const InputDecoration(
                  labelText: 'Reorder Point',
                  prefixIcon: Icon(Icons.inventory_outlined),
                  hintText: '0',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null &&
                      v.isNotEmpty &&
                      int.tryParse(v) == null) {
                    return 'Must be a whole number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // DISCOUNT section
              _SectionHeader(label: 'DISCOUNT / PROMOTION'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile(
                  title: const Text('Enable Discount',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  subtitle: const Text(
                      'Apply a promotional price to this product',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: _hasDiscount,
                  onChanged: (v) => setState(() => _hasDiscount = v),
                  activeThumbColor: AppColors.primaryFg,
                  activeTrackColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_hasDiscount) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DiscountTypeButton(
                        label: 'Percentage (%)',
                        selected: _discountType == 'PERCENTAGE',
                        onTap: () =>
                            setState(() => _discountType = 'PERCENTAGE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DiscountTypeButton(
                        label: 'Fixed (MMK)',
                        selected: _discountType == 'AMOUNT',
                        onTap: () =>
                            setState(() => _discountType = 'AMOUNT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _discountValue,
                  decoration: InputDecoration(
                    labelText: _discountType == 'PERCENTAGE'
                        ? 'Discount %'
                        : 'Discount Amount (MMK)',
                    prefixIcon: const Icon(Icons.percent_outlined),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (_hasDiscount) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start Date',
                        value: _discountStartAt,
                        onPick: (dt) =>
                            setState(() => _discountStartAt = dt),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End Date',
                        value: _discountEndAt,
                        onPick: (dt) =>
                            setState(() => _discountEndAt = dt),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Active toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile(
                  title: const Text('Active',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500)),
                  subtitle: const Text('Product is available for sale',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeThumbColor: AppColors.primaryFg,
                  activeTrackColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 28),

              // Save button — full-width amber
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryFg))
                      : Text(
                          widget.isEdit ? 'Update Product' : 'Create Product',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Section header helper

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

// Discount type toggle button

class _DiscountTypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DiscountTypeButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// Date picker field

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  const _DatePickerField(
      {required this.label, this.value, required this.onPick});

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: AppColors.primaryFg,
                surface: AppColors.surfaceVariant,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? _fmt(value!) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPick(null),
                child: const Icon(Icons.close,
                    size: 16, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

// Barcode scanner sheet

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  final _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Scan Barcode',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (_scanned) return;
                  final raw = capture.barcodes.isNotEmpty
                      ? capture.barcodes.first.rawValue
                      : null;
                  if (raw != null && raw.isNotEmpty) {
                    _scanned = true;
                    Navigator.of(context).pop(raw);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
