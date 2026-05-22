import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification.dart';

class NotificationState {
  final List<AppNotification> items;
  final DateTime? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasMore;

  const NotificationState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasMore = true,
  });

  NotificationState copyWith({
    List<AppNotification>? items,
    DateTime? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasMore,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return NotificationState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotificationViewModel extends StateNotifier<NotificationState> {
  NotificationViewModel(this._repo) : super(const NotificationState());

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
      state = NotificationState(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
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
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
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
    } catch (e) {
      // Rollback on failure and surface the error.
      final rolled = [...state.items];
      final i = rolled.indexWhere((n) => n.id == id);
      if (i != -1) rolled[i] = original;
      state = state.copyWith(
        items: rolled,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> markAllRead() async {
    final now = DateTime.now().toUtc();
    final original = state.items;
    final optimistic =
        original.map((n) => n.isRead ? n : n.copyWith(readAt: now)).toList();
    state = state.copyWith(items: optimistic);
    try {
      await _repo.markAllRead();
    } catch (e) {
      // Rollback on failure and surface the error.
      state = state.copyWith(
        items: original,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}
