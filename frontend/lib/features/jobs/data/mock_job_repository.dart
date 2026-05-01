import 'dart:math';
import '../domain/job.dart';
import 'job_repository.dart';

class MockJobRepository implements JobRepository {
  final List<Job> _jobs = [
    Job(
      id: 'a3f2c891-0001-0000-0000-000000000001',
      userId: 'mock-user-1',
      stlFileId: 'file-001',
      stlFileName: 'bracket_v3.stl',
      recommendationId: 'reco-001',
      printerId: 'printer-prusa-mk4',
      status: Job.printing,
      priority: 3,
      progressPct: 45,
      estimatedDurationS: 9000,
      estimatedCost: 4.20,
      submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      scheduledAt: DateTime.now().subtract(const Duration(hours: 2, minutes: -5)),
      startedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 48)),
    ),
    Job(
      id: 'b7c1d482-0002-0000-0000-000000000002',
      userId: 'mock-user-1',
      stlFileId: 'file-002',
      stlFileName: 'dental_crown.stl',
      recommendationId: 'reco-002',
      priority: 2,
      status: Job.queued,
      progressPct: 0,
      estimatedDurationS: 4500,
      estimatedCost: 2.80,
      submittedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Job(
      id: 'c9d4e573-0003-0000-0000-000000000003',
      userId: 'mock-user-1',
      stlFileId: 'file-003',
      stlFileName: 'prototype_case.3mf',
      printerId: 'printer-prusa-mk3',
      priority: 1,
      status: Job.completed,
      progressPct: 100,
      estimatedDurationS: 14400,
      actualDurationS: 14250,
      estimatedCost: 6.50,
      submittedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      scheduledAt: DateTime.now().subtract(const Duration(days: 1, hours: 6, minutes: -2)),
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 5, minutes: 57)),
      endedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
  ];

  String _newId() =>
      '${Random().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}-mock-0000-0000-000000000000';

  @override
  Future<Job> submitJob({
    required String stlFileId,
    String? recommendationId,
    String? stlFileName,
    int priority = 3,
    String? printerId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final job = Job(
      id: _newId(),
      userId: 'mock-user-1',
      stlFileId: stlFileId,
      stlFileName: stlFileName,
      recommendationId: recommendationId,
      printerId: printerId,
      status: Job.queued,
      priority: priority,
      progressPct: 0,
      estimatedDurationS: 7200,
      estimatedCost: 3.50,
      submittedAt: DateTime.now(),
    );
    _jobs.insert(0, job);
    return job;
  }

  @override
  Future<List<Job>> getMyJobs() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_jobs);
  }

  @override
  Future<Job> getJobById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _jobs.firstWhere((j) => j.id == id,
        orElse: () => throw Exception('Job not found: $id'));
  }

  @override
  Future<Job> cancelJob(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx == -1) throw Exception('Job not found: $id');
    final updated = _jobs[idx].copyWith(status: Job.canceled, progressPct: 0);
    _jobs[idx] = updated;
    return updated;
  }

  @override
  Future<List<Job>> getAllJobs({String? status, String? printerId}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _jobs.where((j) {
      if (status != null && j.status != status) return false;
      if (printerId != null && j.printerId != printerId) return false;
      return true;
    }).toList();
  }

  @override
  Future<Job> suspendJob(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx == -1) throw Exception('Job not found: $id');
    final updated = _jobs[idx].copyWith(status: Job.paused);
    _jobs[idx] = updated;
    return updated;
  }

  @override
  Future<Job> resumeJob(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _jobs.indexWhere((j) => j.id == id);
    if (idx == -1) throw Exception('Job not found: $id');
    final updated = _jobs[idx].copyWith(status: Job.printing);
    _jobs[idx] = updated;
    return updated;
  }
}
