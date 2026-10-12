import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ws/ws_protocol.dart';
import '../../../../core/ws/ws_providers.dart';
import '../../data/job_repository.dart';
import '../../domain/job_detail_state.dart';
import '../providers/job_providers.dart';

/// ViewModel for `JobDetailScreen`.
///
/// Owns the job + slicing fetch, the cancel/suspend/resume actions, and the
/// WS subscription that refreshes the screen on `job.*` / `slicing.*` events.
/// This keeps that logic out of the widget — parity with `UploadViewModel`.
class JobDetailViewModel extends StateNotifier<JobDetailState> {
  final JobRepository _repo;
  final Ref _ref;
  final String jobId;

  JobDetailViewModel(this._repo, this._ref, this.jobId)
      : super(const JobDetailState()) {
    _listenWs();
    load();
  }

  /// Subscribe to the job's WS topic; refresh on each relevant event.
  /// `ref.listen` cleans the subscription up when the provider is disposed.
  void _listenWs() {
    _ref.listen<AsyncValue<WsEvent>>(
      wsTopicEventsProvider(WsTopics.job(jobId)),
      (_, next) {
        next.whenData((event) {
          if (event.type == 'job.status' || event.type == 'job.progress') {
            refresh();
          }
          if (event.type.startsWith('slicing.')) {
            refreshSlicing();
          }
        });
      },
    );
  }

  /// Initial load — job + slicing in parallel.
  Future<void> load() => Future.wait([refresh(), refreshSlicing()]);

  /// Re-fetch the job. Keeps stale data on error if we already have some.
  Future<void> refresh() async {
    try {
      final job = await _repo.getJobById(jobId);
      if (mounted) state = state.copyWith(job: AsyncValue.data(job));
    } catch (e, st) {
      if (mounted && state.job is! AsyncData) {
        state = state.copyWith(job: AsyncValue.error(e, st));
      }
    }
  }

  /// Re-fetch slicing status. Keeps stale data on error if we already have some.
  Future<void> refreshSlicing() async {
    try {
      final slicing = await _repo.getJobSlicing(jobId);
      if (mounted) state = state.copyWith(slicing: AsyncValue.data(slicing));
    } catch (e, st) {
      if (mounted && state.slicing is! AsyncData) {
        state = state.copyWith(slicing: AsyncValue.error(e, st));
      }
    }
  }

  Future<void> cancel() => _runAction(
        () => _repo.cancelJob(jobId),
        setLoading: (v) => state.copyWith(cancelLoading: v),
      );

  Future<void> suspend() => _runAction(
        () => _repo.suspendJob(jobId),
        setLoading: (v) => state.copyWith(suspendLoading: v),
      );

  Future<void> resume() => _runAction(
        () => _repo.resumeJob(jobId),
        setLoading: (v) => state.copyWith(resumeLoading: v),
      );

  /// Shared run-loop for the three mutating actions: flip the loading flag,
  /// call the repo, invalidate the job list, refresh detail; capture errors
  /// into `actionError` for the screen to surface.
  Future<void> _runAction(
    Future<void> Function() action, {
    required JobDetailState Function(bool) setLoading,
  }) async {
    state = setLoading(true).copyWith(clearActionError: true);
    try {
      await action();
      _ref.invalidate(myJobsProvider);
      await Future.wait([refresh(), refreshSlicing()]);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          actionError: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) state = setLoading(false);
    }
  }
}
