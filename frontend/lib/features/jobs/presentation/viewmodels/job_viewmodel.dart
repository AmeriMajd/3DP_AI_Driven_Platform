import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/job_repository.dart';
import '../../domain/job_state.dart';

class JobViewModel extends StateNotifier<JobState> {
  final JobRepository _repo;

  JobViewModel(this._repo) : super(const JobState());

  Future<void> submitJob({
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
    int priority = 3,
    String? printerId,
  }) async {
    state = state.copyWith(
      status: JobStatus.loading,
      clearError: true,
      clearSubmittedJob: true,
    );
    try {
      final job = await _repo.submitJob(
        stlFileId: stlFileId,
        recommendationId: recommendationId,
        stlFileName: stlFileName,
        priority: priority,
        printerId: printerId,
      );
      state = state.copyWith(
        status: JobStatus.success,
        submittedJob: job,
      );
    } catch (e) {
      state = state.copyWith(
        status: JobStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMyJobs() async {
    state = state.copyWith(status: JobStatus.loading, clearError: true);
    try {
      final jobs = await _repo.getMyJobs();
      state = state.copyWith(status: JobStatus.success, jobs: jobs);
    } catch (e) {
      state = state.copyWith(
        status: JobStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> cancelJob(String id) async {
    try {
      final updated = await _repo.cancelJob(id);
      final updatedJobs = state.jobs.map((j) => j.id == id ? updated : j).toList();
      state = state.copyWith(
        jobs: updatedJobs,
        submittedJob: state.submittedJob?.id == id ? updated : state.submittedJob,
      );
    } catch (e) {
      state = state.copyWith(
        status: JobStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void reset() {
    state = const JobState();
  }
}
