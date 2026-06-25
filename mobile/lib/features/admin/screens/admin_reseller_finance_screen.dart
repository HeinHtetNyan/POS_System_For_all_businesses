import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/utils/currency_formatter.dart';

// ignore: unused_element
Dio get _dio => apiClient.dio;

class AdminResellerFinanceScreen extends ConsumerStatefulWidget {
  const AdminResellerFinanceScreen({super.key});

  @override
  ConsumerState<AdminResellerFinanceScreen> createState() =>
      _AdminResellerFinanceScreenState();
}

class _AdminResellerFinanceScreenState
    extends ConsumerState<AdminResellerFinanceScreen> {
  Map<String, dynamic>? _overviewData;
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoadingOverview = false;
  bool _isLoadingPayouts = false;
  String? _overviewError;
  String? _payoutsError;
  String? _filterStatus; // null = all

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([loadOverview(), loadPayouts()]);
  }

  Future<void> loadOverview() async {
    setState(() {
      _isLoadingOverview = true;
      _overviewError = null;
    });
    try {
      final res =
          await apiClient.get('/admin/reseller-finance/overview');
      setState(() {
        _overviewData = Map<String, dynamic>.from(res.data as Map);
      });
    } catch (e) {
      setState(() {
        _overviewError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingOverview = false;
      });
    }
  }

  Future<void> loadPayouts({String? status}) async {
    setState(() {
      _isLoadingPayouts = true;
      _payoutsError = null;
    });
    try {
      final params = <String, dynamic>{'page_size': 20};
      if (status != null) params['status'] = status;
      final res =
          await apiClient.get('/admin/reseller-finance/payouts', params: params);
      final data = res.data as Map;
      final items = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _payouts = items;
      });
    } catch (e) {
      setState(() {
        _payoutsError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingPayouts = false;
      });
    }
  }

  Future<void> _approvePayoutAction(String id) async {
    try {
      await apiClient.post('/admin/reseller-finance/payouts/$id/approve');
      await loadPayouts(status: _filterStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payout approved'),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  Future<void> _showRejectSheet(String id) async {
    final notesController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Reject Payout',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason / Notes (optional)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter rejection reason...',
                  hintStyle: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final notes = notesController.text.trim();
        await apiClient.post(
          '/admin/reseller-finance/payouts/$id/reject',
          data: notes.isNotEmpty ? {'notes': notes} : null,
        );
        await loadPayouts(status: _filterStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payout rejected'),
              backgroundColor: AppColors.errorLight,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.errorLight,
            ),
          );
        }
      }
    }
    notesController.dispose();
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _filterStatus = status;
    });
    loadPayouts(status: status);
  }

  @override
  Widget build(BuildContext context) {
    // go_router context.go is available; referenced in routes but not directly
    // used in this screen's own UI — suppress unused import lint via usage:
    final _ = GoRouter.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Reseller Finance',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => _loadAll(),
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _OverviewSection(
                data: _overviewData,
                isLoading: _isLoadingOverview,
                error: _overviewError,
                onRetry: loadOverview,
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterChipsRow(
                selected: _filterStatus,
                onChanged: _onFilterChanged,
              ),
            ),
            if (_isLoadingPayouts)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if (_payoutsError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorView(
                    message: _payoutsError!,
                    onRetry: () => loadPayouts(status: _filterStatus),
                  ),
                ),
              )
            else if (_payouts.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No payouts found',
                  subtitle: 'Try adjusting your filter',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _PayoutCard(
                      payout: _payouts[i],
                      onApprove: () => _approvePayoutAction(
                          _payouts[i]['id'].toString()),
                      onReject: () =>
                          _showRejectSheet(_payouts[i]['id'].toString()),
                    ),
                    childCount: _payouts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Overview section

class _OverviewSection extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _OverviewSection({
    required this.data,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ),
              GestureDetector(
                onTap: onRetry,
                child: const Icon(Icons.refresh,
                    color: AppColors.error, size: 18),
              ),
            ],
          ),
        ),
      );
    }
    if (data == null) return const SizedBox.shrink();

    final totalResellers = data!['total_resellers'] ?? 0;
    final walletsValue =
        (data!['total_wallets_value'] ?? 0).toDouble();
    final commissionEarned =
        (data!['total_commission_earned'] ?? 0).toDouble();
    final commissionPaidOut =
        (data!['total_commission_paid_out'] ?? 0).toDouble();
    final pendingPayouts =
        (data!['total_pending_payouts'] ?? 0).toDouble();

    final cards = [
      _OverviewCardData(
        label: 'Total Resellers',
        value: totalResellers.toString(),
        icon: Icons.handshake_outlined,
        isCurrency: false,
        highlight: false,
      ),
      _OverviewCardData(
        label: 'Wallets Value',
        value: CurrencyFormatter.format(walletsValue),
        icon: Icons.account_balance_wallet_outlined,
        isCurrency: true,
        highlight: false,
      ),
      _OverviewCardData(
        label: 'Commission Earned',
        value: CurrencyFormatter.format(commissionEarned),
        icon: Icons.trending_up_rounded,
        isCurrency: true,
        highlight: false,
      ),
      _OverviewCardData(
        label: 'Paid Out',
        value: CurrencyFormatter.format(commissionPaidOut),
        icon: Icons.payments_outlined,
        isCurrency: true,
        highlight: false,
      ),
      _OverviewCardData(
        label: 'Pending Payouts',
        value: CurrencyFormatter.format(pendingPayouts),
        icon: Icons.hourglass_empty_rounded,
        isCurrency: true,
        highlight: pendingPayouts > 0,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => _OverviewCard(data: cards[i]),
          ),
        ],
      ),
    );
  }
}

class _OverviewCardData {
  final String label;
  final String value;
  final IconData icon;
  final bool isCurrency;
  final bool highlight;

  const _OverviewCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.isCurrency,
    required this.highlight,
  });
}

class _OverviewCard extends StatelessWidget {
  final _OverviewCardData data;
  const _OverviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final borderColor = data.highlight
        ? AppColors.warning.withValues(alpha: 0.4)
        : AppColors.divider;
    final iconColor =
        data.highlight ? AppColors.warning : AppColors.primary;
    final iconBg = data.highlight
        ? AppColors.warningLight
        : AppColors.primary.withValues(alpha: 0.12);
    final valueColor =
        data.highlight ? AppColors.warning : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(data.icon, size: 15, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                data.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Filter chips

class _FilterChipsRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterChipsRow({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <String?, String>{
      null: 'All',
      'PENDING': 'Pending',
      'APPROVED': 'Approved',
      'REJECTED': 'Rejected',
      'PAID': 'Paid',
    };

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: filters.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryFg
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Payout card

class _PayoutCard extends StatelessWidget {
  final Map<String, dynamic> payout;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PayoutCard({
    required this.payout,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final resellerName = payout['reseller_name'] as String? ?? '';
    final amount = (payout['amount'] ?? 0).toDouble();
    final status = (payout['status'] as String? ?? '').toUpperCase();
    final requestedAt = payout['requested_at'] as String? ?? '';
    final notes = payout['notes'] as String? ?? '';

    String formattedDate = '';
    if (requestedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(requestedAt).toLocal();
        formattedDate =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        formattedDate = requestedAt;
      }
    }

    final isPending = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPending
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    resellerName.isNotEmpty
                        ? resellerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resellerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Requested $formattedDate',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                notes,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.primaryFg,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Approve',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
