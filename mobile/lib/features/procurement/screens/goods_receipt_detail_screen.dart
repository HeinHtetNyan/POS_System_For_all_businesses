import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';

class GoodsReceiptDetailModel {
  final String id;
  final String receiptNumber;
  final String purchaseOrderId;
  final String purchaseOrderNumber;
  final String? supplierName;
  final DateTime receivedAt;
  final String status;
  final List<GoodsReceiptItemModel> items;

  const GoodsReceiptDetailModel({
    required this.id,
    required this.receiptNumber,
    required this.purchaseOrderId,
    required this.purchaseOrderNumber,
    this.supplierName,
    required this.receivedAt,
    required this.status,
    required this.items,
  });

  bool get isDraft => status.toLowerCase() == 'draft';

  double get totalValue => items.fold(
        0.0,
        (sum, item) => sum + item.unitCost * item.quantityReceived,
      );

  factory GoodsReceiptDetailModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return GoodsReceiptDetailModel(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as String? ?? '',
      purchaseOrderId: json['purchase_order_id'] as String? ?? '',
      purchaseOrderNumber:
          json['purchase_order_number'] as String? ?? '',
      supplierName: json['supplier_name'] as String?,
      receivedAt: DateTime.parse(
          json['received_at'] as String? ??
              DateTime.now().toIso8601String()),
      status: json['status'] as String? ?? 'draft',
      items: rawItems
          .map((e) =>
              GoodsReceiptItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GoodsReceiptItemModel {
  final String id;
  final String productName;
  final int quantityOrdered;
  final int quantityReceived;
  final double unitCost;

  const GoodsReceiptItemModel({
    required this.id,
    required this.productName,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
  });

  double get lineValue => unitCost * quantityReceived;

  factory GoodsReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptItemModel(
      id: json['id'] as String,
      productName: json['product_name'] as String? ?? '',
      quantityOrdered: json['quantity_ordered'] as int? ?? 0,
      quantityReceived: json['quantity_received'] as int? ?? 0,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

final _grnDetailProvider =
    FutureProvider.family<GoodsReceiptDetailModel, String>(
        (ref, receiptId) async {
  final dio = apiClient.dio;
  final response =
      await dio.get('${ApiEndpoints.goodsReceipts}/$receiptId');
  return GoodsReceiptDetailModel.fromJson(
      response.data as Map<String, dynamic>);
});

class GoodsReceiptDetailScreen extends ConsumerWidget {
  final String receiptId;
  const GoodsReceiptDetailScreen({super.key, required this.receiptId});

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grnAsync = ref.watch(_grnDetailProvider(receiptId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Goods Receipt',
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
      body: grnAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.refresh(_grnDetailProvider(receiptId)),
        ),
        data: (grn) => ContentWrapper(
          maxWidth: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GrnHeader(grn: grn),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Goods receipts are final upon creation and cannot be modified.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                InfoSection(
                  title: 'RECEIPT INFO',
                  children: [
                    InfoRow(
                      label: 'Receipt #',
                      value: grn.receiptNumber,
                      copyable: true,
                    ),
                    InfoRow(
                      label: 'PO Reference',
                      value: grn.purchaseOrderNumber,
                    ),
                    if (grn.supplierName != null)
                      InfoRow(
                        label: 'Supplier',
                        value: grn.supplierName!,
                      ),
                    InfoRow(
                      label: 'Received Date',
                      value: _fmt(grn.receivedAt),
                      isLast: true,
                    ),
                  ],
                ),
                if (grn.items.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'LINE ITEMS (${grn.items.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...grn.items.map((item) => _GrnItemTile(item: item)),
                  _TotalsSummary(grn: grn),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrnHeader extends StatelessWidget {
  final GoodsReceiptDetailModel grn;
  const _GrnHeader({required this.grn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  grn.receiptNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: grn.status),
            ],
          ),
          if (grn.supplierName != null) ...[
            const SizedBox(height: 6),
            Text(
              grn.supplierName!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrnItemTile extends StatelessWidget {
  final GoodsReceiptItemModel item;
  const _GrnItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QuantityChip(
                      label: 'Ordered: ${item.quantityOrdered}',
                      color: AppColors.textSecondary,
                      bg: AppColors.surfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    _QuantityChip(
                      label: 'Received: ${item.quantityReceived}',
                      color: item.quantityReceived >= item.quantityOrdered
                          ? AppColors.success
                          : AppColors.warning,
                      bg: item.quantityReceived >= item.quantityOrdered
                          ? AppColors.successLight
                          : AppColors.warningLight,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(item.lineValue),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '@ ${CurrencyFormatter.format(item.unitCost)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _QuantityChip(
      {required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _TotalsSummary extends StatelessWidget {
  final GoodsReceiptDetailModel grn;
  const _TotalsSummary({required this.grn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Items',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${grn.items.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                CurrencyFormatter.format(grn.totalValue),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
