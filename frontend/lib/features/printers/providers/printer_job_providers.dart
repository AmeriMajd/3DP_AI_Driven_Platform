import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/domain/job.dart';
import '../../jobs/presentation/providers/job_providers.dart';

final printerActiveJobProvider = Provider.family<Job?, String>((ref, printerId) {
  final jobs = ref.watch(myJobsProvider).valueOrNull ?? const <Job>[];
  for (final j in jobs) {
    if (j.printerId == printerId && j.status == Job.printing) return j;
  }
  return null;
});
