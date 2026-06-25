import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reseller_provider.dart';
import '../data/reseller_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_view.dart';
import '../../../models/reseller_wallet_model.dart';

// H-21: Separate provider to load wallet transactions independently.
final _walletTransactionsProvider = FutureProvider.autoDispose<List<WalletTransactionModel>>((ref) async {
  final raw = await ref.watch(resellerRepositoryProvider).listWalletTransactions();
  return raw
      .map((e) => WalletTransactionModel.fromJson(e))
      .toList();
});

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(resellerWalletProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resellerWalletProvider);
    final txAsync = ref.watch(_walletTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Wallet',
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
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          await ref.read(resellerWalletProvider.notifier).load(refresh: true);
          ref.invalidate(_walletTransactionsProvider);
        },
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () =>
                        ref.read(resellerWalletProvider.notifier).load(refresh: true),
                  )
                : state.wallet == null
                    ? const Center(
                        child: Text(
                          'Wallet not found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        children: [
                          _BalanceGrid(wallet: state.wallet!),
                          const SizedBox(height: 16),
                          _RequestPayoutButton(wallet: state.wallet!),
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Row(
                              children: const [
                                Text(
                                  'Transaction History',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // H-21: Render transactions from the separate API call.
                          txAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary),
                              ),
                            ),
                            error: (_, __) => const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              child: Text(
                                'Failed to load transactions',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            data: (txList) => txList.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 32),
                                    child: Center(
                                      child: Column(
                                        children: const [
                                          Icon(
                                            Icons.receipt_long_outlined,
                                            size: 40,
                                            color: AppColors.textDisabled,
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'No transactions yet',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: txList
                                        .map((tx) => _TransactionTile(tx: tx))
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
      ),
    );
  }
}

// 2×2 balance card grid (4 columns on tablet)

class _BalanceGrid extends StatelessWidget {
  final ResellerWalletModel wallet;
  const _BalanceGrid({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final cards = [
      _BalanceCardData(
        label: 'Available Balance',
        value: CurrencyFormatter.format(
          wallet.availableBalance,
          currency: wallet.currencyCode,
        ),
        subtitle: wallet.currencyCode,
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
        bgColor: AppColors.successLight,
        borderColor: AppColors.success.withValues(alpha: 0.3),
      ),
      _BalanceCardData(
        label: 'Locked Balance',
        value: CurrencyFormatter.format(
          wallet.lockedBalance,
          currency: wallet.currencyCode,
        ),
        subtitle: 'Pending payout',
        icon: Icons.lock_outline,
        color: AppColors.warning,
        bgColor: AppColors.warningLight,
        borderColor: AppColors.warning.withValues(alpha: 0.3),
      ),
      _BalanceCardData(
        label: 'Total Paid Out',
        value: CurrencyFormatter.format(
          wallet.totalPaidOut,
          currency: wallet.currencyCode,
        ),
        subtitle: 'All time',
        icon: Icons.payments_outlined,
        color: AppColors.textSecondary,
        bgColor: AppColors.surfaceVariant,
        borderColor: AppColors.divider,
      ),
      _BalanceCardData(
        label: 'Commission Rate',
        value: '${wallet.commissionRatePct.toStringAsFixed(2)}%',
        subtitle: 'Per paid subscription',
        icon: Icons.percent_outlined,
        color: AppColors.primary,
        bgColor: AppColors.primaryLight.withValues(alpha: 0.25),
        borderColor: AppColors.primary.withValues(alpha: 0.3),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: isTablet
          ? Row(
              children: cards
                  .map(
                    (c) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: c == cards.last ? 0 : 12,
                        ),
                        child: _BalanceCard(data: c),
                      ),
                    ),
                  )
                  .toList(),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BalanceCard(data: cards[0]),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _BalanceCard(data: cards[1]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _BalanceCard(data: cards[2]),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _BalanceCard(data: cards[3]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _BalanceCardData {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _BalanceCardData({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}

class _BalanceCard extends StatelessWidget {
  final _BalanceCardData data;
  const _BalanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Request Payout button & dialog

class _RequestPayoutButton extends ConsumerWidget {
  final ResellerWalletModel wallet;
  const _RequestPayoutButton({required this.wallet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resellerWalletProvider);
    final canRequest = wallet.availableBalance >= wallet.minPayoutAmount &&
        wallet.availableBalance > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canRequest ? AppColors.primary : AppColors.surfaceVariant,
            foregroundColor:
                canRequest ? AppColors.primaryFg : AppColors.textDisabled,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: state.isLoading || !canRequest
              ? null
              : () => _showPayoutDialog(context, ref, wallet),
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            canRequest
                ? 'Request Payout'
                : wallet.availableBalance <= 0
                    ? 'No Balance Available'
                    : 'Minimum ${CurrencyFormatter.format(wallet.minPayoutAmount, currency: wallet.currencyCode)} Required',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _showPayoutDialog(
      BuildContext context, WidgetRef ref, ResellerWalletModel wallet) {
    final amountController = TextEditingController(
        text: wallet.availableBalance.toStringAsFixed(0));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => _PayoutDialog(
        wallet: wallet,
        amountController: amountController,
        reasonController: reasonController,
        onConfirm: (amount, reason) async {
          Navigator.pop(ctx);
          final ok = await ref
              .read(resellerWalletProvider.notifier)
              .requestPayout(amount, reason: reason);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                ok
                    ? 'Payout requested successfully'
                    : 'Failed to request payout',
              ),
              backgroundColor: ok ? AppColors.success : AppColors.error,
            ));
          }
        },
      ),
    );
  }
}

class _PayoutDialog extends StatefulWidget {
  final ResellerWalletModel wallet;
  final TextEditingController amountController;
  final TextEditingController reasonController;
  final Future<void> Function(double amount, String? reason) onConfirm;

  const _PayoutDialog({
    required this.wallet,
    required this.amountController,
    required this.reasonController,
    required this.onConfirm,
  });

  @override
  State<_PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<_PayoutDialog> {
  bool _submitting = false;

  InputDecoration _fieldDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceVariant,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.wallet.availableBalance;
    final minAmount = widget.wallet.minPayoutAmount;
    final currency = widget.wallet.currencyCode;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      title: const Text(
        'Request Payout',
        style: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info row: available + minimum
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Available',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        CurrencyFormatter.format(maxAmount, currency: currency),
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Minimum payout',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      Text(
                        CurrencyFormatter.format(minAmount, currency: currency),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Amount field
            TextField(
              controller: widget.amountController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration(
                'Amount (max ${CurrencyFormatter.formatCompact(maxAmount)})',
              ).copyWith(
                prefixText: '$currency ',
                prefixStyle: const TextStyle(color: AppColors.textSecondary),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            // Reason field
            TextField(
              controller: widget.reasonController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration('Reason (optional)'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.primaryFg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _submitting
              ? null
              : () async {
                  final amount =
                      double.tryParse(widget.amountController.text) ?? 0;
                  if (amount <= 0 || amount > maxAmount) return;
                  if (amount < minAmount) return;
                  final reason = widget.reasonController.text.trim().isEmpty
                      ? null
                      : widget.reasonController.text.trim();
                  setState(() => _submitting = true);
                  try {
                    await widget.onConfirm(amount, reason);
                  } finally {
                    if (mounted) setState(() => _submitting = false);
                  }
                },
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryFg,
                  ),
                )
              : const Text('Request'),
        ),
      ],
    );
  }
}

// Transaction tile

class _TransactionTile extends ConsumerWidget {
  final WalletTransactionModel tx;
  const _TransactionTile({required this.tx});

  Future<void> _cancelPayout(BuildContext ctx, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        title: const Text(
          'Cancel Payout?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This will cancel your pending payout request.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(resellerRepositoryProvider).cancelPayout(tx.id);
      ref.invalidate(resellerWalletProvider);
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPendingPayout = tx.isPendingPayout;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPendingPayout
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isPendingPayout
                    ? AppColors.warningLight
                    : tx.isCredit
                        ? AppColors.successLight
                        : AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPendingPayout
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : tx.isCredit
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                isPendingPayout
                    ? Icons.hourglass_top_rounded
                    : tx.isCredit
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                color: isPendingPayout
                    ? AppColors.warning
                    : tx.isCredit
                        ? AppColors.success
                        : AppColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description ?? tx.displayLabel,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isPendingPayout) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _cancelPayout(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${tx.isCredit ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isPendingPayout
                    ? AppColors.warning
                    : tx.isCredit
                        ? AppColors.success
                        : AppColors.error,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
