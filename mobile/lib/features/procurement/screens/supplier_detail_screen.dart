import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_row.dart';
import '../../../models/purchase_order_model.dart';
import '../data/procurement_repository.dart';
import 'supplier_form_screen.dart';

final _supplierPurchaseOrdersProvider =
    FutureProvider.family<List<PurchaseOrderModel>, String>((ref, supplierId) async {
  final result = await ref
      .read(procurementRepositoryProvider)
      .listPurchaseOrders(supplierId: supplierId, pageSize: 10);
  return result.items;
});

final _supplierPayablesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, supplierId) async {
  final result = await ref
      .read(procurementRepositoryProvider)
      .listPayables(supplierId: supplierId, pageSize: 10);
  return result.items;
});

class SupplierDetailScreen extends ConsumerStatefulWidget {
  final SupplierModel supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  late SupplierModel _supplier;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
  }

  Future<void> _refreshPOs() async {
    ref.invalidate(_supplierPurchaseOrdersProvider(_supplier.id));
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SupplierFormScreen(supplier: _supplier),
      ),
    );
    if (result == true && mounted) {
      // Reload supplier from list then update local state
      try {
        final suppliers =
            await ref.read(procurementRepositoryProvider).getSuppliers();
        final updated =
            suppliers.firstWhere((s) => s.id == _supplier.id, orElse: () => _supplier);
        if (mounted) setState(() => _supplier = updated);
      } catch (_) {}
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Supplier',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${_supplier.name}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(procurementRepositoryProvider).deleteSupplier(_supplier.id);
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posAsync =
        ref.watch(_supplierPurchaseOrdersProvider(_supplier.id));
    final payablesAsync =
        ref.watch(_supplierPayablesProvider(_supplier.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _supplier.name,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
            tooltip: 'Edit Supplier',
            onPressed: _openEdit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildStatusBanner(),
          _buildSectionHeader('CONTACT'),
          _buildContactCard(),
          _buildSectionHeader('PAYMENT SUMMARY'),
          _buildPaymentSummary(payablesAsync),
          _buildSectionHeader('PURCHASE ORDERS'),
          _buildPOSection(posAsync),
          _buildSectionHeader('PAYABLES'),
          _buildPayablesSection(payablesAsync),
          const SizedBox(height: 24),
          _buildDeleteButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: _supplier.isActive ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _supplier.isActive ? AppColors.success : AppColors.error,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            _supplier.isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: _supplier.isActive ? AppColors.success : AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            _supplier.isActive ? 'Active Supplier' : 'Inactive Supplier',
            style: TextStyle(
              color: _supplier.isActive ? AppColors.success : AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final hasContact = (_supplier.phone?.isNotEmpty ?? false) ||
        (_supplier.email?.isNotEmpty ?? false) ||
        (_supplier.address?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: hasContact
          ? Column(
              children: [
                if (_supplier.phone?.isNotEmpty ?? false)
                  InfoRow(
                    label: 'Phone',
                    value: _supplier.phone!,
                  ),
                if (_supplier.email?.isNotEmpty ?? false) ...[
                  if (_supplier.phone?.isNotEmpty ?? false)
                    const Divider(color: AppColors.divider, height: 20),
                  InfoRow(
                    label: 'Email',
                    value: _supplier.email!,
                  ),
                ],
                if (_supplier.address?.isNotEmpty ?? false) ...[
                  if ((_supplier.phone?.isNotEmpty ?? false) ||
                      (_supplier.email?.isNotEmpty ?? false))
                    const Divider(color: AppColors.divider, height: 20),
                  InfoRow(
                    label: 'Address',
                    value: _supplier.address!,
                    isLast: true,
                  ),
                ],
              ],
            )
          : const Text(
              'No contact information',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
    );
  }

  Widget _buildPOSection(AsyncValue<List<PurchaseOrderModel>> posAsync) {
    return Column(
      children: [
        posAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load purchase orders: $e',
                style:
                    const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Center(
                    child: Text(
                      'No purchase orders yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              );
            }
            return Column(
              children: orders
                  .map((po) => _POCard(po: po))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await context.push<bool>(
                    '/procurement/new?supplier_id=${_supplier.id}');
                if (result == true) _refreshPOs();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Purchase Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary(AsyncValue<List<Map<String, dynamic>>> async) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.all(16),
      child: async.when(
        loading: () => const Center(
          child: SizedBox(
            height: 40,
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
        error: (_, __) => const Text(
          'Could not load payment summary',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        data: (payables) {
          double totalOrdered = 0;
          double totalPaid = 0;
          for (final p in payables) {
            totalOrdered +=
                (p['total_amount'] as num?)?.toDouble() ?? 0;
            totalPaid +=
                (p['paid_amount'] as num?)?.toDouble() ?? 0;
          }
          final outstanding = totalOrdered - totalPaid;
          return Row(
            children: [
              _SummaryCell(
                  label: 'Total Ordered',
                  value: _fmtAmount(totalOrdered),
                  color: AppColors.info),
              _vDivider(),
              _SummaryCell(
                  label: 'Total Paid',
                  value: _fmtAmount(totalPaid),
                  color: AppColors.success),
              _vDivider(),
              _SummaryCell(
                  label: 'Outstanding',
                  value: _fmtAmount(outstanding),
                  color: outstanding > 0
                      ? AppColors.warning
                      : AppColors.textSecondary),
            ],
          );
        },
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        color: AppColors.divider,
      );

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _buildPayablesSection(AsyncValue<List<Map<String, dynamic>>> async) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (payables) {
        if (payables.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: Text(
                'No payables yet',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          );
        }
        return Column(
          children: payables
              .map((p) => _PayableCard(payable: p))
              .toList(),
        );
      },
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _isDeleting ? null : _confirmDelete,
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.error),
                )
              : const Icon(Icons.delete_outline, size: 18),
          label: Text(_isDeleting ? 'Deleting…' : 'Delete Supplier'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PayableCard extends StatelessWidget {
  final Map<String, dynamic> payable;

  const _PayableCard({required this.payable});

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return AppColors.success;
      case 'PARTIAL':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = payable['status'] as String? ?? 'OPEN';
    final amount = (payable['total_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (payable['paid_amount'] as num?)?.toDouble() ?? 0.0;
    final dueDate = payable['due_date'] as String?;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (dueDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Due $dueDate',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (paidAmount > 0 && paidAmount < amount) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: paidAmount / amount,
                        backgroundColor:
                            AppColors.surfaceVariant,
                        color: AppColors.success,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid ${paidAmount.toStringAsFixed(0)} / ${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amount.toStringAsFixed(0)} MMK',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (paidAmount > 0) ...[
                  Text(
                    '${(amount - paidAmount).toStringAsFixed(0)} left',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _POCard extends StatelessWidget {
  final PurchaseOrderModel po;
  const _POCard({required this.po});

  Color _statusColor() {
    switch (po.status) {
      case 'ORDERED':
        return AppColors.info;
      case 'RECEIVED':
        return AppColors.success;
      case 'PARTIAL':
        return AppColors.warning;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          po.orderNumber.isNotEmpty ? po.orderNumber : po.id,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${po.orderDate.year}-${po.orderDate.month.toString().padLeft(2, '0')}-${po.orderDate.day.toString().padLeft(2, '0')}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor, width: 0.5),
              ),
              child: Text(
                po.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${po.totalAmount.toStringAsFixed(2)} MMK',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
