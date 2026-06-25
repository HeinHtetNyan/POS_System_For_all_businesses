import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../cashier_session/providers/session_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cashier_session_model.dart';

class CashierDashboard extends ConsumerWidget {
  const CashierDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final sessionState = ref.watch(sessionProvider);
    final session = sessionState.session;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: AppColors.primaryFg,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.firstName ?? 'Cashier'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryFg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cashier',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Session status card
            _SessionCard(session: session),
            const SizedBox(height: 20),

            // KPI row (if session open)
            if (session?.isOpen == true) ...[
              Row(
                children: [
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Opening Balance',
                      value: CurrencyFormatter.format(session!.openingBalance),
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _KpiCard(
                      icon: Icons.schedule_outlined,
                      label: 'Session Started',
                      value: _formatTime(session.openedAt),
                      iconColor: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Quick actions
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (_, c) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: Responsive.gridCols(
                  c.maxWidth,
                  phone: 2,
                  tablet: 3,
                  wide: 4,
                ),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _ActionCard(
                    icon: Icons.point_of_sale_rounded,
                    label: 'New Sale',
                    color: AppColors.primary,
                    onTap: session?.isOpen == true
                        ? () => context.go('/pos')
                        : null,
                  ),
                  _ActionCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Order History',
                    color: AppColors.secondary,
                    onTap: () => context.push('/orders'),
                  ),
                  _ActionCard(
                    icon: Icons.people_outlined,
                    label: 'Customers',
                    color: AppColors.info,
                    onTap: () => context.push('/customers'),
                  ),
                  _ActionCard(
                    icon: session?.isOpen == true
                        ? Icons.lock_outlined
                        : Icons.lock_open_outlined,
                    label: session?.isOpen == true
                        ? 'Close Session'
                        : 'Open Session',
                    color: session?.isOpen == true
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () => session?.isOpen == true
                        ? context.push('/session/close')
                        : context.push('/session/open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _SessionCard extends StatelessWidget {
  final CashierSessionModel? session;

  const _SessionCard({this.session});

  @override
  Widget build(BuildContext context) {
    final isOpen = session?.isOpen == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.successLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpen
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isOpen ? AppColors.success : AppColors.warning,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'Session Open' : 'No Active Session',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isOpen ? AppColors.success : AppColors.warning,
                  ),
                ),
                if (session != null)
                  Text(
                    'Opening balance: ${CurrencyFormatter.format(session!.openingBalance)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
