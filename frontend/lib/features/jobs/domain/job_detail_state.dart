import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'job.dart';
import 'job_slicing.dart';

/// Immutable state for the job detail screen.
///
/// Holds the job + slicing async values plus per-action loading flags.
/// Owned by [JobDetailViewModel]; the screen only reads it.
class JobDetailState {
  final AsyncValue<Job> job;
  final AsyncValue<JobSlicing> slicing;
  final bool cancelLoading;
  final bool suspendLoading;
  final bool resumeLoading;
  final String? actionError;

  const JobDetailState({
    this.job = const AsyncValue.loading(),
    this.slicing = const AsyncValue.loading(),
    this.cancelLoading = false,
    this.suspendLoading = false,
    this.resumeLoading = false,
    this.actionError,
  });

  JobDetailState copyWith({
    AsyncValue<Job>? job,
    AsyncValue<JobSlicing>? slicing,
    bool? cancelLoading,
    bool? suspendLoading,
    bool? resumeLoading,
    String? actionError,
    bool clearActionError = false,
  }) {
    return JobDetailState(
      job: job ?? this.job,
      slicing: slicing ?? this.slicing,
      cancelLoading: cancelLoading ?? this.cancelLoading,
      suspendLoading: suspendLoading ?? this.suspendLoading,
      resumeLoading: resumeLoading ?? this.resumeLoading,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}
