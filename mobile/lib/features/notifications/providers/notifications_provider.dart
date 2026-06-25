import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notifications_repository.dart';
import '../../../models/notification_model.dart';

class NotificationsState {
  final List<NotificationModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;
  final int page;
  final int unreadCount;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
    this.page = 1,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    int? page,
    int? unreadCount,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repo;
  Timer? _pollingTimer;

  NotificationsNotifier(this._repo) : super(const NotificationsState());

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      state = const NotificationsState(isLoading: true);
    } else if (state.items.isEmpty) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final results = await Future.wait([
        _repo.listNotifications(page: 1),
        _repo.getUnreadCount(),
      ]);

      final notifResult = results[0] as ({List<NotificationModel> items, int total});
      state = state.copyWith(
        items: notifResult.items,
        isLoading: false,
        hasMore: notifResult.items.length >= 20,
        page: 1,
        unreadCount: results[1] as int,
        clearError: true,
      );

      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        try {
          final count = await _repo.getUnreadCount();
          if (mounted) state = state.copyWith(unreadCount: count);
        } catch (_) {}
      });
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.listNotifications(page: state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.items.length >= 20,
        page: state.page + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markRead(String id) async {
    final previousItems = state.items;
    final previousUnreadCount = state.unreadCount;
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(isRead: true, readAt: DateTime.now()) : n)
          .toList(),
      unreadCount: (state.unreadCount - 1).clamp(0, 999),
    );
    try {
      await _repo.markRead(id);
    } catch (_) {
      state = state.copyWith(
        items: previousItems,
        unreadCount: previousUnreadCount,
      );
    }
  }

  Future<void> markAllRead() async {
    final previousItems = state.items;
    final previousUnreadCount = state.unreadCount;
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
      unreadCount: 0,
    );
    try {
      await _repo.markAllRead();
    } catch (_) {
      state = state.copyWith(
        items: previousItems,
        unreadCount: previousUnreadCount,
      );
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
        (ref) {
  return NotificationsNotifier(ref.watch(notificationsRepositoryProvider));
});

final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
