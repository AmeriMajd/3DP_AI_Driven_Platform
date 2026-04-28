import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';
import '../widgets/job_card.dart';

class JobQueueScreen extends ConsumerWidget {
  const JobQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(error: e.toString(), onRetry: () => ref.invalidate(myJobsProvider)),
          data: (jobs) => RefreshIndicator(
            color: const Color(0xFF4B6BFB),
            onRefresh: () async => ref.invalidate(myJobsProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _Header(jobs: jobs),
                if (jobs.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => JobCard(
                        job: jobs[i],
                        onTap: () => context.push(
                          '/jobs/${jobs[i].id}',
                          extra: jobs[i],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final List<Job> jobs;
  const _Header({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final active = jobs.where((j) => j.status == Job.printing).length;
    final queued = jobs.where((j) => j.status == Job.queued).length;
    final completed = jobs.where((j) => j.status == Job.completed).length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text('My Jobs',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                ),
                Consumer(
                  builder: (context, ref, _) => IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF4B6BFB), size: 22),
                    onPressed: () => ref.invalidate(myJobsProvider),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            Text('${jobs.length} jobs · pull to refresh',
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Active', value: active, color: const Color(0xFFFF9500))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Queued', value: queued, color: const Color(0xFF8E8E93))),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Completed', value: completed, color: const Color(0xFF34C759))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF4B6BFB).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.print_outlined,
                  color: Color(0xFF4B6BFB), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('No jobs yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black)),
            const SizedBox(height: 6),
            const Text(
              'Submit a recommendation to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFFF3B30), size: 40),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4B6BFB)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
