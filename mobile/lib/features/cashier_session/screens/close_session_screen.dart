import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class CloseSessionScreen extends ConsumerStatefulWidget {
  const CloseSessionScreen({super.key});

  @override
  ConsumerState<CloseSessionScreen> createState() =>
      _CloseSessionScreenState();
}

class _CloseSessionScreenState extends ConsumerState<CloseSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countedCashController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  double get _countedCash =>
      double.tryParse(_countedCashController.text) ?? 0.0;

  @override
  void dispose() {
    _countedCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _closeSession() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(sessionProvider.notifier)
        .closeSession(
          closingBalance: _countedCash,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (success && mounted) {
      context.go('/dashboard/cashier');
    }
  }

  InputDecoration _fieldDecoration({
    String? prefixText,
    String? hintText,
  }) {
    return InputDecoration(
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.session;

    ref.listen<SessionState>(sessionProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(sessionProvider.notifier).clearError();
      }
    });

    final openingBalance = session?.openingBalance ?? 0.0;
    // CashierSessionModel does not expose cashSales directly — show N/A.
    const cashSalesLabel = 'N/A';
    // expectedCash cannot be computed without cashSales; show N/A too.
    const expectedCashLabel = 'N/A';
    // Use 0.0 for variance calculation baseline (counted − opening only).
    final expectedCashForVariance = openingBalance;

    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
    final openedAtText = session != null
        ? dateFormatter.format(session.openedAt.toLocal())
        : '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Close Session'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.divider, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Session Summary card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Session Summary',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: AppColors.divider,
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Opened at', openedAtText),
                      _buildSummaryRow(
                        'Opening balance',
                        CurrencyFormatter.format(openingBalance),
                      ),
                      _buildSummaryRow(
                        'Cash sales',
                        cashSalesLabel,
                        valueColor: AppColors.success,
                      ),
                      const SizedBox(height: 4),
                      Container(height: 1, color: AppColors.divider),
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Expected cash',
                        expectedCashLabel,
                        valueColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Reconciliation card
                StatefulBuilder(
                  builder: (context, setCardState) {
                    final counted = _countedCash;
                    final variance = counted - expectedCashForVariance;
                    final isExact = variance == 0.0;
                    final isOver = variance > 0.0;
                    final varianceColor = isExact
                        ? AppColors.primary
                        : isOver
                            ? AppColors.success
                            : AppColors.error;
                    final varianceLabel =
                        isExact ? 'Exact' : isOver ? 'Over' : 'Short';
                    final varianceIcon = isExact
                        ? Icons.check_circle_outline_rounded
                        : isOver
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.balance_rounded,
                                  color: AppColors.info,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Reconciliation',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Counted Cash',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _countedCashController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            decoration:
                                _fieldDecoration(prefixText: 'MMK '),
                            onChanged: (_) => setCardState(() {}),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Enter the counted cash amount';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Variance display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: varianceColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: varianceColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  varianceIcon,
                                  color: varianceColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Variance · $varianceLabel',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: varianceColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        variance >= 0
                                            ? '+${CurrencyFormatter.format(variance)}'
                                            : CurrencyFormatter.format(
                                                variance),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: varianceColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Expected\n${CurrencyFormatter.format(expectedCashForVariance)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Notes card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        decoration: _fieldDecoration(
                          hintText: 'Any notes about this session…',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Close Session button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: sessionState.isLoading ? null : _closeSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: sessionState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryFg,
                            ),
                          )
                        : const Icon(
                            Icons.lock_rounded,
                            color: AppColors.primaryFg,
                          ),
                    label: Text(
                      sessionState.isLoading ? 'Closing...' : 'Close Session',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryFg,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
