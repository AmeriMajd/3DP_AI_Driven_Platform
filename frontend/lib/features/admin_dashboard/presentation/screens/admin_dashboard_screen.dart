import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_dashboard_providers.dart';
import '../widgets/active_job_card.dart';
import '../widgets/dashboard_tokens.dart';
import '../widgets/filter_chips.dart';
import '../widgets/jobs_stacked_chart.dart';
import '../widgets/kpi_card.dart';
import '../widgets/recent_job_row.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/section_header.dart';
import '../widgets/time_range.dart';
import '../widgets/top_users_list.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(kpisProvider);
    ref.invalidate(revenueProvider);
    ref.invalidate(jobsByStatusProvider);
    ref.invalidate(activeJobsProvider);
    ref.invalidate(recentJobsProvider);
    ref.invalidate(topUsersProvider);
    await Future.wait([
      ref.read(kpisProvider.future),
      ref.read(revenueProvider.future),
      ref.read(jobsByStatusProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardRangeProvider);
    return Container(
      color: DT.bg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: DT.accent,
          onRefresh: () => _refresh(ref),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Row(
                    children: [
                      TimeRangeSelector(
                        value: range,
                        onChange: (v) =>
                            ref.read(dashboardRangeProvider.notifier).state = v,
                      ),
                      const Spacer(),
                      _IconBtn(
                        icon: Icons.search_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _KpiGrid()),
              SliverToBoxAdapter(child: _RevenueSection()),
              SliverToBoxAdapter(child: _JobsBySection()),
              SliverToBoxAdapter(child: _ActiveNowSection()),
              SliverToBoxAdapter(child: _RecentJobsSection()),
              SliverToBoxAdapter(child: _TopUsersSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: DT.surface1,
          border: Border.all(color: DT.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: DT.text2),
      ),
    );
  }
}

class _KpiGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kpisProvider);
    final loading = async.isLoading && !async.hasValue;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          children: [
            _KpiRow(
              left: KpiCard(label: '', value: '', sub: '', delta: 0, icon: Icons.bolt, accent: DT.accent, loading: true),
              right: KpiCard(label: '', value: '', sub: '', delta: 0, icon: Icons.bolt, accent: DT.accent, loading: true),
            ),
            SizedBox(height: 10),
            _KpiRow(
              left: KpiCard(label: '', value: '', sub: '', delta: 0, icon: Icons.bolt, accent: DT.accent, loading: true),
              right: KpiCard(label: '', value: '', sub: '', delta: 0, icon: Icons.bolt, accent: DT.accent, loading: true),
            ),
          ],
        ),
      );
    }

    final k = async.value;
    if (k == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        children: [
          _KpiRow(
            left: KpiCard(
              label: 'Active jobs',
              value: k.activeJobs.value.toStringAsFixed(0),
              sub: k.activeJobs.sub,
              delta: k.activeJobs.deltaPct,
              icon: Icons.bolt_rounded,
              accent: StatusColors.of('printing').fg,
            ),
            right: KpiCard(
              label: 'Revenue today',
              value: '\$${k.revenueToday.value.toStringAsFixed(0)}',
              sub: k.revenueToday.sub,
              delta: k.revenueToday.deltaPct,
              icon: Icons.attach_money_rounded,
              accent: StatusColors.of('completed').fg,
            ),
          ),
          const SizedBox(height: 10),
          _KpiRow(
            left: KpiCard(
              label: 'Success rate',
              value: k.successRate.value.toStringAsFixed(1),
              unit: '%',
              sub: k.successRate.sub,
              delta: k.successRate.deltaPct,
              icon: Icons.check_rounded,
              accent: DT.accent,
            ),
            right: KpiCard(
              label: 'Queue depth',
              value: k.queueDepth.value.toStringAsFixed(0),
              sub: k.queueDepth.sub,
              delta: k.queueDepth.deltaPct,
              icon: Icons.layers_rounded,
              accent: StatusColors.of('queued').fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _KpiRow({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _RevenueSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(revenueProvider);
    final range = ref.watch(dashboardRangeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: DashCard(
        child: async.when(
          loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _ChartError(onRetry: () => ref.invalidate(revenueProvider)),
          data: (data) {
            final total = data.fold<double>(0, (a, b) => a + b.value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Revenue',
                  sub: '· daily, $range',
                  trailing: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoneyCompact(total),
                        style: const TextStyle(
                          color: DT.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                RevenueChart(data: data),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ChartError({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, color: StatusColors.of('failed').fg, size: 24),
          const SizedBox(height: 8),
          const Text(
            "Couldn't load revenue",
            style: TextStyle(color: DT.text, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lost connection to analytics. Try again.',
            style: TextStyle(color: DT.text3, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: DT.text,
              side: const BorderSide(color: DT.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsBySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(jobsByStatusProvider);
    final range = ref.watch(dashboardRangeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: DashCard(
        child: async.when(
          loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
          error: (_, _) => _ChartError(onRetry: () => ref.invalidate(jobsByStatusProvider)),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Jobs by status', sub: '· daily, $range'),
              JobsStackedChart(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveNowSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeJobsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SectionHeader(title: 'Active now', live: true),
          ),
          async.when(
            loading: () => const SizedBox(height: 124),
            error: (_, _) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Could not load active jobs', style: TextStyle(color: DT.text3, fontSize: 12)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('No active jobs', style: TextStyle(color: DT.text3, fontSize: 12)),
                );
              }
              return SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => ActiveJobCard(job: list[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentJobsSection extends ConsumerWidget {
  static const _allOptions = ['all', 'printing', 'queued', 'failed', 'completed'];
  static const _labels = {
    'all': 'All',
    'printing': 'Printing',
    'queued': 'Queued',
    'failed': 'Failed',
    'completed': 'Completed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(recentJobsFilterProvider);
    final async = ref.watch(recentJobsProvider);

    final chips = _allOptions
        .map((k) => FilterChipOption(key: k, label: _labels[k]!))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent jobs',
            trailing: Icon(Icons.more_horiz_rounded, color: DT.text3, size: 20),
          ),
          DashFilterChips(
            value: filter,
            options: chips,
            onChange: (v) => ref.read(recentJobsFilterProvider.notifier).state = v,
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: DT.surface1,
              border: Border.all(color: DT.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Could not load recent jobs', style: TextStyle(color: DT.text3, fontSize: 12)),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const _Empty(
                    title: 'No jobs in range',
                    desc: 'Try a different time range or clear the active filter.',
                  );
                }
                final shown = list.take(8).toList();
                return Column(
                  children: [
                    for (int i = 0; i < shown.length; i++)
                      RecentJobRow(job: shown[i], last: i == shown.length - 1),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String desc;
  const _Empty({required this.title, required this.desc});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: DT.textDisabled, size: 44),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: DT.text2, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, textAlign: TextAlign.center, style: const TextStyle(color: DT.text3, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

class _TopUsersSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topUsersProvider);
    final range = ref.watch(dashboardRangeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Top users', sub: '· $range by spend'),
          DashCard(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('Could not load top users', style: TextStyle(color: DT.text3, fontSize: 12)),
              data: (list) => TopUsersList(users: list),
            ),
          ),
        ],
      ),
    );
  }
}
