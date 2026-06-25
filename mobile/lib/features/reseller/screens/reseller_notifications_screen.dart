import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/shimmer_loader.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

typedef _Filter = String;

const _filterAll = 'all';
const _filterUnread = 'unread';
const _filterRead = 'read';

// ---------------------------------------------------------------------------
// Helper utilities
// ---------------------------------------------------------------------------

IconData _iconForType(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'INVENTORY':
      return Icons.warehouse_outlined;
    case 'SUBSCRIPTION':
      return Icons.credit_card_outlined;
    case 'PAYMENT':
      return Icons.payments_outlined;
    case 'WARNING':
      return Icons.warning_amber_outlined;
    case 'SUCCESS':
      return Icons.check_circle_outline;
    default:
      return Icons.notifications_outlined;
  }
}

String _timeAgo(String? raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ResellerNotificationsScreen extends ConsumerStatefulWidget {
  const ResellerNotificationsScreen({super.key});

  @override
  ConsumerState<ResellerNotificationsScreen> createState() =>
      _ResellerNotificationsScreenState();
}

class _ResellerNotificationsScreenState
    extends ConsumerState<ResellerNotificationsScreen> {
  _Filter _filter = _filterAll;
  int _page = 1;
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  final _scrollController = ScrollController();

  Dio get _dio => apiClient.dio;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Map<String, dynamic> _buildParams(int page) {
    final params = <String, dynamic>{'page': page, 'page_size': 20};
    if (_filter == _filterUnread) params['read'] = false;
    if (_filter == _filterRead) params['read'] = true;
    return params;
  }

  Future<void> _load({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (refresh) {
        _items.clear();
        _page = 1;
        _hasMore = true;
      }
    });
    try {
      final resp = await _dio.get(
        '/notifications',
        queryParameters: _buildParams(1),
      );
      final data = resp.data;
      final List<dynamic> list = data is Map ? (data['items'] ?? data['results'] ?? []) : (data as List? ?? []);
      setState(() {
        _items
          ..clear()
          ..addAll(list.cast<Map<String, dynamic>>());
        _page = 1;
        _hasMore = list.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final resp = await _dio.get(
        '/notifications',
        queryParameters: _buildParams(_page + 1),
      );
      final data = resp.data;
      final List<dynamic> list = data is Map ? (data['items'] ?? data['results'] ?? []) : (data as List? ?? []);
      setState(() {
        _items.addAll(list.cast<Map<String, dynamic>>());
        _page += 1;
        _hasMore = list.length >= 20;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;
    final alreadyRead = item['is_read'] as bool? ?? false;
    if (!alreadyRead) {
      try {
        await _dio.post('/notifications/$id/read');
        final idx = _items.indexWhere((n) => n['id'] == id);
        if (idx != -1 && mounted) {
          setState(() => _items[idx] = {..._items[idx], 'is_read': true});
        }
      } catch (_) {}
    }
    if (!mounted) return;
    _showDetail(item);
  }

  Future<void> _markAllRead() async {
    try {
      await _dio.post('/notifications/read-all');
      if (mounted) {
        setState(() {
          for (var i = 0; i < _items.length; i++) {
            _items[i] = {..._items[i], 'is_read': true};
          }
        });
      }
    } catch (_) {}
  }

  void _showDetail(Map<String, dynamic> item) {
    final title = item['title'] as String? ?? 'Notification';
    final message = item['message'] as String? ?? '';
    final type = item['type'] as String?;
    final timeRaw = item['created_at'] as String?;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar + close
                Row(
                  children: [
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => ctx.pop(),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Icon + title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconForType(type),
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (timeRaw != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _timeAgo(timeRaw),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 16),

                // Full message
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helpers

  bool get _hasUnread => _items.any((n) => !(n['is_read'] as bool? ?? false));

  void _setFilter(_Filter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load(refresh: true);
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          _FilterRow(current: _filter, onChanged: _setFilter),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const ShimmerList(itemCount: 8, itemHeight: 80);
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => _load(refresh: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return EmptyView(
        icon: Icons.notifications_outlined,
        title: _filter == _filterUnread
            ? 'No Unread Notifications'
            : _filter == _filterRead
                ? 'No Read Notifications'
                : 'No Notifications',
        subtitle: _filter == _filterUnread
            ? 'You are all caught up.'
            : 'Notifications will appear here.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _NotificationTile(
            data: _items[index],
            onTap: () => _markRead(_items[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final _Filter current;
  final void Function(_Filter) onChanged;

  const _FilterRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: current == _filterAll,
            onTap: () => onChanged(_filterAll),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Unread',
            selected: current == _filterUnread,
            onTap: () => onChanged(_filterUnread),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Read',
            selected: current == _filterRead,
            onTap: () => onChanged(_filterRead),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificationTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Notification';
    final message = data['message'] as String? ?? '';
    final type = data['type'] as String?;
    final timeRaw = data['created_at'] as String?;
    final isRead = data['is_read'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRead ? AppColors.divider : AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isRead
                      ? Colors.transparent
                      : AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isRead
                              ? AppColors.surfaceVariant
                              : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _iconForType(type),
                          size: 18,
                          color: isRead ? AppColors.textSecondary : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _timeAgo(timeRaw),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Unread dot
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
