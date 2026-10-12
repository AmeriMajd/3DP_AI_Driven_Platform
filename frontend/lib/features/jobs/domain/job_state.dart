import 'job.dart';

enum JobStatus { initial, loading, success, error }

class JobState {
  final JobStatus status;
  final Job? submittedJob;
  final List<Job> jobs;
  final String? errorMessage;

  const JobState({
    this.status = JobStatus.initial,
    this.submittedJob,
    this.jobs = const [],
    this.errorMessage,
  });

  JobState copyWith({
    JobStatus? status,
    Job? submittedJob,
    List<Job>? jobs,
    String? errorMessage,
    bool clearSubmittedJob = false,
    bool clearError = false,
  }) {
    return JobState(
      status: status ?? this.status,
      submittedJob: clearSubmittedJob ? null : (submittedJob ?? this.submittedJob),
      jobs: jobs ?? this.jobs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
