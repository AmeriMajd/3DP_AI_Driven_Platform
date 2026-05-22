import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ws/ws_protocol.dart';
import '../../../../core/ws/ws_providers.dart';
import '../../../../shared/services/storage_service.dart';
import '../../data/notification_repository.dart';
import '../../data/notification_repository_impl.dart';
import '../../domain/app_notification.dart';
import '../viewmodels/notification_viewmodel.dart';

export '../viewmodels/notification_viewmodel.dart' show NotificationState;

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

final notificationListProvider =
    StateNotifierProvider<NotificationViewModel, NotificationState>(
  (ref) {
    final notifier = NotificationViewModel(
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

void refreshUnreadCount(WidgetRef ref) {
  ref.invalidate(_unreadCountFallbackProvider);
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
