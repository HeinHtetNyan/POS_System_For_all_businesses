import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/notifications_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../models/notification_model.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(notificationsProvider.notifier).load());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final hasUnread = state.unreadCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          hasUnread
              ? 'Notifications (${state.unreadCount})'
              : 'Notifications',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: () => ref
                  .read(notificationsProvider.notifier)
                  .markAllRead(),
              icon: const Icon(Icons.done_all,
                  size: 18, color: AppColors.primary),
              label: const Text('Mark all read',
                  style: TextStyle(color: AppColors.primary)),
            ),
          IconButton(
            icon: const Icon(Icons.tune_outlined,
                color: AppColors.textPrimary),
            tooltip: 'Preferences',
            onPressed: () =>
                context.push('/notifications/preferences'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref
            .read(notificationsProvider.notifier)
            .load(refresh: true),
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
            : state.error != null
                ? ErrorView(
                    message: state.error!,
                    onRetry: () => ref
                        .read(notificationsProvider.notifier)
                        .load(refresh: true),
                  )
                : Column(
                    children: [
                      // Type filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            for (final type in [
                              'all',
                              'system',
                              'inventory',
                              'procurement',
                              'customer',
                              'subscription',
                              'security',
                            ])
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 6),
                                child: FilterChip(
                                  label: Text(
                                    type == 'all'
                                        ? 'All Types'
                                        : type[0].toUpperCase() +
                                            type.substring(1),
                                  ),
                                  selected: _typeFilter == type,
                                  onSelected: (_) => setState(
                                      () => _typeFilter = type),
                                  selectedColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: _typeFilter == type
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  backgroundColor:
                                      AppColors.surfaceVariant,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: _typeFilter == type
                                          ? AppColors.primary
                                          : AppColors.divider,
                                    ),
                                  ),
                                  showCheckmark: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Notifications list
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final filtered = _typeFilter == 'all'
                                ? state.items
                                : state.items
                                    .where((n) =>
                                        n.notificationType
                                            .toLowerCase() ==
                                        _typeFilter)
                                    .toList();

                            if (filtered.isEmpty) {
                              return const EmptyView(
                                icon: Icons
                                    .notifications_none_outlined,
                                title: 'No notifications',
                                subtitle: 'You\'re all caught up!',
                              );
                            }

                            return ListView.builder(
                              controller: _scrollController,
                              itemCount: filtered.length +
                                  (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= filtered.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child:
                                          CircularProgressIndicator(
                                              color:
                                                  AppColors.primary),
                                    ),
                                  );
                                }
                                final n = filtered[i];
                                return _NotificationTile(
                                  notification: n,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NotificationDetailScreen(
                                                notification: n),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// Notification Tile

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile(
      {required this.notification, required this.onTap});

  Color get _iconColor {
    switch (notification.notificationType) {
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
      default:
        return AppColors.textSecondary;
    }
  }

  // Background tint for the icon circle, matched to type
  Color get _iconBg {
    switch (notification.notificationType) {
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
      default:
        return AppColors.surfaceVariant;
    }
  }

  IconData get _icon {
    switch (notification.notificationType) {
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
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.isUnread;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread
            ? AppColors.surfaceVariant
            : AppColors.surface,
        // Subtle left accent for unread items
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isUnread)
              Container(
                width: 3,
                color: AppColors.primary,
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isUnread ? 13 : 16,
                  right: 16,
                  top: 14,
                  bottom: 14,
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Icon circle
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon,
                          size: 20, color: _iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                    color: isUnread
                                        ? AppColors
                                            .textPrimary
                                        : AppColors
                                            .textSecondary,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration:
                                      const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: const TextStyle(
                                fontSize: 13,
                                color:
                                    AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timeAgo(notification.createdAt),
                            style: const TextStyle(
                                fontSize: 11,
                                color:
                                    AppColors.textDisabled),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
