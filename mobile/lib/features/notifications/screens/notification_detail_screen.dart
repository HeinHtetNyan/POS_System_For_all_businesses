import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notifications_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/notification_model.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final NotificationModel notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  late NotificationModel _notification;

  @override
  void initState() {
    super.initState();
    _notification = widget.notification;
    if (_notification.isUnread) {
      Future.microtask(() async {
        await ref
            .read(notificationsProvider.notifier)
            .markRead(_notification.id);
        if (mounted) {
          setState(() {
            _notification = _notification.copyWith(isRead: true);
          });
        }
      });
    }
  }

  Color get _typeColor {
    switch (_notification.notificationType) {
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.error:
        return AppColors.error;
      case NotificationType.order:
        return AppColors.primary;
      case NotificationType.payment:
        return AppColors.secondary;
      case NotificationType.inventory:
        return AppColors.info;
      case NotificationType.procurement:
        return AppColors.warning;
      case NotificationType.customer:
        return AppColors.secondary;
      case NotificationType.subscription:
        return AppColors.primary;
      case NotificationType.security:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _typeBg {
    switch (_notification.notificationType) {
      case NotificationType.warning:
        return AppColors.warningLight;
      case NotificationType.success:
        return AppColors.successLight;
      case NotificationType.error:
        return AppColors.errorLight;
      case NotificationType.order:
        return AppColors.primary.withValues(alpha: 0.15);
      case NotificationType.payment:
        return AppColors.secondary.withValues(alpha: 0.15);
      case NotificationType.inventory:
        return AppColors.infoLight;
      case NotificationType.procurement:
        return AppColors.warningLight;
      case NotificationType.customer:
        return AppColors.secondary.withValues(alpha: 0.15);
      case NotificationType.subscription:
        return AppColors.primary.withValues(alpha: 0.15);
      case NotificationType.security:
        return AppColors.errorLight;
      default:
        return AppColors.surfaceVariant;
    }
  }

  IconData get _typeIcon {
    switch (_notification.notificationType) {
      case NotificationType.order:
        return Icons.receipt_long_outlined;
      case NotificationType.payment:
        return Icons.payments_outlined;
      case NotificationType.inventory:
        return Icons.warehouse_outlined;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.procurement:
        return Icons.local_shipping_outlined;
      case NotificationType.customer:
        return Icons.people_outline;
      case NotificationType.subscription:
        return Icons.card_membership_outlined;
      case NotificationType.security:
        return Icons.security_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  String _typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'INFO':
        return 'Info';
      case 'WARNING':
        return 'Warning';
      case 'SUCCESS':
        return 'Success';
      case 'ERROR':
        return 'Error';
      case 'ORDER':
        return 'Order';
      case 'PAYMENT':
        return 'Payment';
      case 'INVENTORY':
        return 'Inventory';
      case 'SYSTEM':
        return 'System';
      case 'PROCUREMENT':
        return 'Procurement';
      case 'CUSTOMER':
        return 'Customer';
      case 'SUBSCRIPTION':
        return 'Subscription';
      case 'SECURITY':
        return 'Security';
      default:
        return type;
    }
  }

  /// Attempt to extract an order ID from the actionUrl.
  /// Expects patterns like /orders/[uuid] or orders/[uuid]
  String? _extractOrderId() {
    final url = _notification.actionUrl;
    if (url == null) return null;
    final regex = RegExp(r'orders/([a-zA-Z0-9\-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  String? _extractProductId() {
    final url = _notification.actionUrl;
    if (url == null) return null;
    final regex = RegExp(r'products/([a-zA-Z0-9\-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _extractOrderId();
    final productId = _extractProductId();
    final isOrder = _notification.notificationType == NotificationType.order ||
        orderId != null;
    final isInventory =
        _notification.notificationType == NotificationType.inventory ||
            productId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _notification.title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_notification.isUnread)
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined,
                  color: AppColors.primary),
              tooltip: 'Mark as read',
              onPressed: () async {
                await ref
                    .read(notificationsProvider.notifier)
                    .markRead(_notification.id);
                if (mounted) {
                  setState(() {
                    _notification = _notification.copyWith(isRead: true);
                  });
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + type badge card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _typeBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_typeIcon, size: 26, color: _typeColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _typeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _typeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            _typeLabel(_notification.notificationType),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _typeColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time_outlined,
                                size: 13, color: AppColors.textDisabled),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(_notification.createdAt),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDisabled),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_notification.isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Metadata card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _MetaRow(
                    icon: Icons.schedule_outlined,
                    label: 'Received',
                    value: _formatDate(_notification.createdAt),
                  ),
                  if (_notification.readAt != null) ...[
                    const Divider(height: 16, color: AppColors.divider),
                    _MetaRow(
                      icon: Icons.mark_email_read_outlined,
                      label: 'Read At',
                      value: _formatDate(_notification.readAt!),
                    ),
                  ],
                  if (_notification.expiresAt != null) ...[
                    const Divider(height: 16, color: AppColors.divider),
                    _MetaRow(
                      icon: Icons.timer_off_outlined,
                      label: 'Expires',
                      value: _formatDate(_notification.expiresAt!),
                      valueColor: _notification.isExpired
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ],
                  const Divider(height: 16, color: AppColors.divider),
                  _MetaRow(
                    icon: Icons.flag_outlined,
                    label: 'Priority',
                    valueWidget: _PriorityBadge(
                        priority: _notification.priority),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Message body card
            Container(
              width: double.infinity,
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
                    'MESSAGE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _notification.message,
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            if (isOrder && orderId != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View Order',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => context.push('/orders/$orderId'),
                ),
              )
            else if (isOrder)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View Orders',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

            if (isInventory && productId != null) ...[
              if (isOrder) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.info,
                    side: const BorderSide(color: AppColors.info),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('View Product',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => context.push('/products/$productId'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;

  const _MetaRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        valueWidget ??
            Text(
              value ?? '',
              style: TextStyle(
                  fontSize: 12,
                  color: valueColor ?? AppColors.textSecondary),
            ),
      ],
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  Color get _color {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.textSecondary;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        priority[0].toUpperCase() + priority.substring(1).toLowerCase(),
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _color),
      ),
    );
  }
}
