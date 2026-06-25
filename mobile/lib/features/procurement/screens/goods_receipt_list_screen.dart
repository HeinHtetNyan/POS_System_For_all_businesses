import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../core/widgets/status_badge.dart';

class GoodsReceiptModel {
  final String id;
  final String receiptNumber;
  final DateTime receivedAt;
  final String status;
  final int totalItems;

  const GoodsReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.receivedAt,
    required this.status,
    required this.totalItems,
  });

  factory GoodsReceiptModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>? ?? [];
    return GoodsReceiptModel(
      id: json['id'] as String,
      receiptNumber: json['receipt_number'] as String? ?? '',
      receivedAt: DateTime.parse(
          json['received_at'] as String? ?? DateTime.now().toIso8601String()),
      status: json['status'] as String? ?? 'draft',
      totalItems: items.length,
    );
  }
}

final _grnsForPoProvider =
    FutureProvider.family<List<GoodsReceiptModel>, String>((ref, poId) async {
  final dio = apiClient.dio;
  final response = await dio.get(
    ApiEndpoints.goodsReceipts,
    queryParameters: {'purchase_order_id': poId},
  );
  final data = response.data as Map<String, dynamic>;
  final rawItems = data['items'] as List<dynamic>? ?? (response.data is List ? response.data as List<dynamic> : []);
  return rawItems
      .map((e) => GoodsReceiptModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class GoodsReceiptListScreen extends ConsumerWidget {
  final String poId;
  const GoodsReceiptListScreen({super.key, required this.poId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grnsAsync = ref.watch(_grnsForPoProvider(poId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Goods Receipts',
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryFg,
        onPressed: () =>
            context.go('/procurement/receipts/new?po_id=$poId'),
        child: const Icon(Icons.add),
      ),
      body: ContentWrapper(
        child: grnsAsync.when(
          loading: () => const ShimmerList(itemCount: 6, itemHeight: 88),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.refresh(_grnsForPoProvider(poId)),
          ),
          data: (grns) => RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async => ref.refresh(_grnsForPoProvider(poId)),
            child: grns.isEmpty
                ? const EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No goods receipts',
                    subtitle:
                        'Tap + to record a new goods receipt for this order',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: grns.length,
                    itemBuilder: (_, i) => _GrnCard(
                      grn: grns[i],
                      onTap: () =>
                          context.go('/procurement/receipts/${grns[i].id}'),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GrnCard extends StatelessWidget {
  final GoodsReceiptModel grn;
  final VoidCallback? onTap;
  const _GrnCard({required this.grn, this.onTap});

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      grn.receiptNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  StatusBadge(status: grn.status),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    _fmt(grn.receivedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.inventory_2_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    '${grn.totalItems} item${grn.totalItems != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
