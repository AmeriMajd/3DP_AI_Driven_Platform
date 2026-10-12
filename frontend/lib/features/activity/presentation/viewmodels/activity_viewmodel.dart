import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/activity_repository.dart';
import '../../domain/activity_log.dart';

class ActivityState {
  final ActivityFilters filters;
  final List<ActivityLog> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const ActivityState({
    this.filters = const ActivityFilters(),
    this.items = const [],
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  bool get hasMore => items.length < total;

  ActivityState copyWith({
    ActivityFilters? filters,
    List<ActivityLog>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
  }) {
    return ActivityState(
      filters: filters ?? this.filters,
      items: items ?? this.items,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ActivityViewModel extends StateNotifier<ActivityState> {
  final ActivityRepository _repo;
  static const int _pageSize = 50;

  ActivityViewModel(this._repo) : super(const ActivityState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _repo.list(
        dateFrom: state.filters.dateFrom,
        dateTo: state.filters.dateTo,
        eventType: state.filters.eventType,
        severity: state.filters.severity,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      state = state.copyWith(
        items: page.items,
        total: page.total,
        loading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.list(
        dateFrom: state.filters.dateFrom,
        dateTo: state.filters.dateTo,
        eventType: state.filters.eventType,
        severity: state.filters.severity,
        limit: _pageSize,
        offset: state.items.length,
      );
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        total: page.total,
        loadingMore: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setFilters(ActivityFilters f) {
    state = state.copyWith(filters: f);
    refresh();
  }
}
