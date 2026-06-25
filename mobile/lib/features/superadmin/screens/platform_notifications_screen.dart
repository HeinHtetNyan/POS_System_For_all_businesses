import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _PlatformNotification {
  final String id;
  final String title;
  final String message;
  final String priority;
  final bool isRead;
  final String? tenantId;
  final DateTime createdAt;

  const _PlatformNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.isRead,
    this.tenantId,
    required this.createdAt,
  });

  bool get isUnread => !isRead;

  factory _PlatformNotification.fromJson(Map<String, dynamic> json) {
    return _PlatformNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      priority: (json['priority'] as String? ?? 'NORMAL').toUpperCase(),
      isRead: json['is_read'] as bool? ?? false,
      tenantId: json['tenant_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  _PlatformNotification copyWith({bool? isRead}) => _PlatformNotification(
        id: id,
        title: title,
        message: message,
        priority: priority,
        isRead: isRead ?? this.isRead,
        tenantId: tenantId,
        createdAt: createdAt,
      );
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _PlatformNotifState {
  final List<_PlatformNotification> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final String readFilter; // 'all' | 'unread' | 'read'
  final String priorityFilter; // 'ALL' | 'CRITICAL' | 'HIGH' | 'NORMAL' | 'LOW'

  const _PlatformNotifState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.readFilter = 'all',
    this.priorityFilter = 'ALL',
  });

  int get unreadCount => items.where((n) => n.isUnread).length;

  _PlatformNotifState copyWith({
    List<_PlatformNotification>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? page,
    String? readFilter,
    String? priorityFilter,
    bool clearError = false,
  }) =>
      _PlatformNotifState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        readFilter: readFilter ?? this.readFilter,
        priorityFilter: priorityFilter ?? this.priorityFilter,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _PlatformNotifNotifier
    extends StateNotifier<_PlatformNotifState> {
  _PlatformNotifNotifier() : super(const _PlatformNotifState());

  Dio get _dio => apiClient.dio;

  static const int _pageSize = 25;

  bool? get _readParam {
    switch (state.readFilter) {
      case 'unread':
        return false;
      case 'read':
        return true;
      default:
        return null;
    }
  }

  Future<List<_PlatformNotification>> _fetch(int page) async {
    // NOTE: This currently calls the personal inbox endpoint (/notifications).
    // Once a platform-wide notifications backend endpoint is available it should
    // be replaced with something like /admin/notifications/platform.
    final params = <String, dynamic>{
      'page': page,
      'page_size': _pageSize,
      if (_readParam != null) 'read': _readParam,
    };
    final response =
        await _dio.get('/notifications', queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    var items = rawItems
        .map((e) =>
            _PlatformNotification.fromJson(e as Map<String, dynamic>))
        .toList();

    // Client-side priority filter (if API doesn't support it natively)
    if (state.priorityFilter != 'ALL') {
      items = items
          .where((n) => n.priority == state.priorityFilter)
          .toList();
    }
    return items;
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh || state.items.isEmpty) {
      state = _PlatformNotifState(
        isLoading: true,
        readFilter: state.readFilter,
        priorityFilter: state.priorityFilter,
      );
    }
    try {
      final items = await _fetch(1);
      state = state.copyWith(
        items: items,
        isLoading: false,
        hasMore: items.length >= _pageSize,
        page: 1,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final items = await _fetch(state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: items.length >= _pageSize,
        page: state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setReadFilter(String filter) {
    if (state.readFilter == filter) return;
    state = state.copyWith(readFilter: filter);
    load(refresh: true);
  }

  void setPriorityFilter(String priority) {
    if (state.priorityFilter == priority) return;
    state = state.copyWith(priorityFilter: priority);
    load(refresh: true);
  }

  Future<void> markRead(String id) async {
    try {
      await _dio.post('/notifications/$id/read');
      state = state.copyWith(
        items: state.items
            .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _platformNotifProvider = StateNotifierProvider.autoDispose<
    _PlatformNotifNotifier, _PlatformNotifState>(
  (_) => _PlatformNotifNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PlatformNotificationsScreen extends ConsumerStatefulWidget {
  const PlatformNotificationsScreen({super.key});

  @override
  ConsumerState<PlatformNotificationsScreen> createState() =>
      _PlatformNotificationsScreenState();
}

class _PlatformNotificationsScreenState
    extends ConsumerState<PlatformNotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(_platformNotifProvider.notifier).load());
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
      ref.read(_platformNotifProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_platformNotifProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Platform Notifications',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            if (state.unreadCount > 0)
              Text(
                '${state.unreadCount} unread',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () =>
                  ref.read(_platformNotifProvider.notifier).markAllRead(),
              icon: const Icon(Icons.done_all,
                  size: 18, color: AppColors.primary),
              label: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      floatingActionButton: Tooltip(
        message: 'Broadcast not yet available',
        child: FloatingActionButton(
          onPressed: null,
          backgroundColor: AppColors.surfaceVariant,
          child: const Icon(Icons.campaign_outlined, color: AppColors.textSecondary),
        ),
      ),
      body: Column(
        children: [
          // Read filter chips
          _ReadFilterRow(selected: state.readFilter),

          // Priority filter chips
          _PriorityFilterRow(selected: state.priorityFilter),

          Container(height: 1, color: AppColors.divider),

          // Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => ref
                  .read(_platformNotifProvider.notifier)
                  .load(refresh: true),
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : state.error != null
                      ? ErrorView(
                          message: state.error!,
                          onRetry: () => ref
                              .read(_platformNotifProvider.notifier)
                              .load(refresh: true),
                        )
                      : state.items.isEmpty
                          ? const EmptyView(
                              icon: Icons.notifications_none_outlined,
                              title: 'No notifications',
                              subtitle: 'No platform notifications found.',
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: state.items.length +
                                  (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= state.items.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                          color: AppColors.primary),
                                    ),
                                  );
                                }
                                final n = state.items[i];
                                return _PlatformNotifTile(
                                  notification: n,
                                  onTap: () => ref
                                      .read(_platformNotifProvider.notifier)
                                      .markRead(n.id),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Read filter row
// ---------------------------------------------------------------------------

class _ReadFilterRow extends ConsumerWidget {
  final String selected;
  const _ReadFilterRow({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      ('all', 'All'),
      ('unread', 'Unread'),
      ('read', 'Read'),
    ];

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: filters.map((f) {
          final isSelected = selected == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref
                  .read(_platformNotifProvider.notifier)
                  .setReadFilter(f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryFg
                        : AppColors.textSecondary,
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

// ---------------------------------------------------------------------------
// Priority filter row
// ---------------------------------------------------------------------------

class _PriorityFilterRow extends ConsumerWidget {
  final String selected;
  const _PriorityFilterRow({required this.selected});

  static const _priorities = [
    ('ALL', 'ALL'),
    ('CRITICAL', 'CRITICAL'),
    ('HIGH', 'HIGH'),
    ('NORMAL', 'NORMAL'),
    ('LOW', 'LOW'),
  ];

  Color _labelColor(String p, bool isSelected) {
    if (isSelected) return AppColors.primaryFg;
    switch (p) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'NORMAL':
        return AppColors.info;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: _priorities.map((p) {
          final isSelected = selected == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref
                  .read(_platformNotifProvider.notifier)
                  .setPriorityFilter(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _labelColor(p.$1, isSelected),
                    letterSpacing: 0.5,
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

// ---------------------------------------------------------------------------
// Notification tile
// ---------------------------------------------------------------------------

class _PlatformNotifTile extends StatelessWidget {
  final _PlatformNotification notification;
  final VoidCallback onTap;

  const _PlatformNotifTile({
    required this.notification,
    required this.onTap,
  });

  Color get _priorityColor {
    switch (notification.priority) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'NORMAL':
        return AppColors.info;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _priorityBg {
    switch (notification.priority) {
      case 'CRITICAL':
        return AppColors.errorLight;
      case 'HIGH':
        return AppColors.warningLight;
      case 'NORMAL':
        return AppColors.infoLight;
      case 'LOW':
        return AppColors.surfaceVariant;
      default:
        return AppColors.surfaceVariant;
    }
  }

  IconData get _priorityIcon {
    switch (notification.priority) {
      case 'CRITICAL':
        return Icons.error_outline;
      case 'HIGH':
        return Icons.warning_amber_outlined;
      case 'NORMAL':
        return Icons.info_outline;
      case 'LOW':
        return Icons.notifications_outlined;
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
        color: isUnread ? AppColors.surfaceVariant : AppColors.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Unread accent bar
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority icon circle
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _priorityBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_priorityIcon,
                          size: 20, color: _priorityColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row
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
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Message
                          Text(
                            notification.message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Bottom row: priority badge + time + tenant
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Priority badge
                              _PriorityBadge(
                                  priority: notification.priority),
                              // Time
                              Text(
                                _timeAgo(notification.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textDisabled,
                                ),
                              ),
                              // Tenant chip
                              if (notification.tenantId != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                        color: AppColors.divider),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        size: 10,
                                        color: AppColors.textDisabled,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Business: ${notification.tenantId}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textDisabled,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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

// ---------------------------------------------------------------------------
// Priority badge chip
// ---------------------------------------------------------------------------

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  Color get _color {
    switch (priority) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'NORMAL':
        return AppColors.info;
      case 'LOW':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Color get _bg {
    switch (priority) {
      case 'CRITICAL':
        return AppColors.errorLight;
      case 'HIGH':
        return AppColors.warningLight;
      case 'NORMAL':
        return AppColors.infoLight;
      case 'LOW':
        return AppColors.surfaceVariant;
      default:
        return AppColors.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
