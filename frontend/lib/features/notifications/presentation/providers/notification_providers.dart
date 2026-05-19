import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ws/ws_protocol.dart';
import '../../../../core/ws/ws_providers.dart';
import '../../../../shared/services/storage_service.dart';
import '../../data/notification_repository.dart';
import '../../data/notification_repository_impl.dart';
import '../../domain/app_notification.dart';

/// Repository singleton.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(),
);

/// Currently selected filter chip on the history screen.
final notificationFilterProvider = StateProvider<NotificationFilter>(
  (_) => NotificationFilter.all,
);

/// Cached current user id. Resolved once from secure storage.
final currentUserIdProvider = FutureProvider<String?>(
  (_) => StorageService.getUserId(),
);

// ── Notification store ───────────────────────────────────────────────────────

class NotificationListState {
  final List<AppNotification> items;
  final DateTime? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;

  const NotificationListState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
  });

  NotificationListState copyWith({
    List<AppNotification>? items,
    DateTime? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return NotificationListState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotificationListNotifier extends StateNotifier<NotificationListState> {
  NotificationListNotifier(this._repo) : super(const NotificationListState());

  final NotificationRepository _repo;
  static const _pageSize = 30;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final page = await _repo.list(limit: _pageSize);
      state = NotificationListState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repo.list(
        cursor: state.nextCursor,
        limit: _pageSize,
      );
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        isLoadingMore: false,
        hasMore: page.nextCursor != null,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Prepend a freshly received WS notification. Dedupe by id in case the
  /// REST list and WS event race (e.g. open screen during a print finish).
  void prepend(AppNotification n) {
    if (state.items.any((x) => x.id == n.id)) return;
    state = state.copyWith(items: [n, ...state.items]);
  }

  Future<void> markRead(String id) async {
    final idx = state.items.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final original = state.items[idx];
    if (original.isRead) return;

    // Optimistic update.
    final optimistic = [...state.items];
    optimistic[idx] = original.copyWith(readAt: DateTime.now().toUtc());
    state = state.copyWith(items: optimistic);

    try {
      final updated = await _repo.markRead(id);
      final next = [...state.items];
      final i = next.indexWhere((n) => n.id == id);
      if (i != -1) next[i] = updated;
      state = state.copyWith(items: next);
    } catch (_) {
      // Rollback on failure.
      final rolled = [...state.items];
      final i = rolled.indexWhere((n) => n.id == id);
      if (i != -1) rolled[i] = original;
      state = state.copyWith(items: rolled);
    }
  }

  Future<void> markAllRead() async {
    final now = DateTime.now().toUtc();
    final original = state.items;
    final optimistic = original
        .map((n) => n.isRead ? n : n.copyWith(readAt: now))
        .toList();
    state = state.copyWith(items: optimistic);
    try {
      await _repo.markAllRead();
    } catch (_) {
      state = state.copyWith(items: original);
    }
  }
}

final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>(
  (ref) {
    final notifier = NotificationListNotifier(
      ref.watch(notificationRepositoryProvider),
    );
    // First load.
    Future.microtask(notifier.refresh);
    return notifier;
  },
);

// ── Unread count (bell badge) ────────────────────────────────────────────────

/// Derived count — drops to live state once the list loaded. Falls back to
/// the dedicated REST endpoint while the list is empty (cold start / before
/// the user opens the history screen).
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationListProvider);
  if (list.items.isNotEmpty) {
    return list.items.where((n) => !n.isRead).length;
  }
  return ref.watch(_unreadCountFallbackProvider).maybeWhen(
        data: (n) => n,
        orElse: () => 0,
      );
});

/// Cold-start fallback. Pulled on first read, refreshed by [refreshUnreadCount].
final _unreadCountFallbackProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  try {
    return await repo.getUnreadCount();
  } catch (_) {
    return 0;
  }
});

Future<void> refreshUnreadCount(WidgetRef ref) async {
  // ignore: unused_result
  ref.refresh(_unreadCountFallbackProvider);
}

// ── WS listener — connects user:{id} topic to the store ──────────────────────

/// Subscribes to `user:{currentUserId}` and forwards `notification.new`
/// events into the list store. Returns a `StreamSubscription` so the
/// caller can keep the listener alive for the app's lifetime.
final notificationWsListenerProvider = Provider<AsyncValue<void>>((ref) {
  final userIdAsync = ref.watch(currentUserIdProvider);
  return userIdAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (userId) {
      if (userId == null || userId.isEmpty) {
        return const AsyncValue.data(null);
      }
      final topic = WsTopics.user(userId);
      final stream = ref.watch(wsTopicEventsProvider(topic).stream);
      final sub = stream.listen((event) {
        if (event.type != 'notification.new') return;
        try {
          final n = AppNotification.fromJson(event.data);
          ref.read(notificationListProvider.notifier).prepend(n);
        } catch (_) {
          // Malformed payload — ignore silently; backend is source of truth.
        }
      });
      ref.onDispose(sub.cancel);
      return const AsyncValue.data(null);
    },
  );
});
