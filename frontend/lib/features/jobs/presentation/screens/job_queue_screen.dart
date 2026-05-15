import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../printers/domain/printer.dart';
import '../../../printers/domain/printer_filter.dart';
import '../../../printers/providers/printer_providers.dart';
import '../../domain/job.dart';
import '../providers/job_providers.dart';

// Design tokens — Screen G (Timeline / activity feed)
class _T {
  static const appBg = Color(0xFFF4F4F7);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFECECF1);
  static const borderSoft = Color(0xFFF1F1F6);
  static const ink = Color(0xFF1F2030);
  static const body = Color(0xFF5C5E76);
  static const muted = Color(0xFF9295A8);
  static const violet = Color(0xFF7C5CFF);
  static const violetSoft = Color(0xFFEDE7FF);
  static const mint = Color(0xFF19A88F);
  static const mintSoft = Color(0xFFDBF1EB);
  static const peach = Color(0xFFD88B3F);
  static const peachSoft = Color(0xFFFBE6CF);
  static const coral = Color(0xFFD55B5B);
  static const coralSoft = Color(0xFFFADCDC);
  static const slate = Color(0xFF8488A0);
  static const slateSoft = Color(0xFFE8E9EE);
}

class _StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  final Color dot;
  const _StatusStyle(this.label, this.fg, this.bg, this.dot);
}

_StatusStyle _styleFor(String status) {
  switch (status) {
    case Job.printing:
      return const _StatusStyle('Printing', _T.violet, _T.violetSoft, _T.violet);
    case Job.queued:
    case Job.scheduled:
      return const _StatusStyle('Queued', _T.peach, _T.peachSoft, _T.peach);
    case Job.completed:
      return const _StatusStyle('Completed', _T.mint, _T.mintSoft, _T.mint);
    case Job.canceled:
      return const _StatusStyle('Cancelled', _T.coral, _T.coralSoft, _T.coral);
    case Job.failed:
      return const _StatusStyle('Failed', _T.coral, _T.coralSoft, _T.coral);
    case Job.paused:
      return const _StatusStyle('Paused', _T.slate, _T.slateSoft, _T.slate);
    default:
      return _StatusStyle(status.toUpperCase(), _T.slate, _T.slateSoft, _T.slate);
  }
}

class JobQueueScreen extends ConsumerStatefulWidget {
  const JobQueueScreen({super.key});

  @override
  ConsumerState<JobQueueScreen> createState() => _JobQueueScreenState();
}

class _JobQueueScreenState extends ConsumerState<JobQueueScreen>
    with SingleTickerProviderStateMixin {
  String _filter = 'all';
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool _matches(Job j) {
    switch (_filter) {
      case 'all':
        return true;
      case 'printing':
        return j.status == Job.printing;
      case 'queued':
        return j.status == Job.queued || j.status == Job.scheduled;
      case 'completed':
        return j.status == Job.completed;
      case 'cancelled':
        return j.status == Job.canceled || j.status == Job.failed;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(myJobsProvider);
    final printers =
        ref.watch(printersListProvider(const PrinterFilter())).valueOrNull ??
            const <Printer>[];
    final printerById = {for (final p in printers) p.id: p};
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: _T.appBg,
      body: SafeArea(
        child: jobsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _T.violet)),
          error: (e, _) => _ErrorState(
            error: e.toString(),
            onRetry: () => ref.invalidate(myJobsProvider),
          ),
          data: (jobs) {
            final liveCount = jobs.where((j) => j.status == Job.printing).length;
            final counts = {
              'all': jobs.length,
              'printing':
                  jobs.where((j) => j.status == Job.printing).length,
              'queued': jobs
                  .where((j) =>
                      j.status == Job.queued || j.status == Job.scheduled)
                  .length,
              'completed':
                  jobs.where((j) => j.status == Job.completed).length,
              'cancelled': jobs
                  .where((j) =>
                      j.status == Job.canceled || j.status == Job.failed)
                  .length,
            };

            final visible = jobs.where(_matches).toList();
            final groups = _groupByDay(visible);

            return RefreshIndicator(
              color: _T.violet,
              onRefresh: () async => ref.invalidate(myJobsProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      liveCount: liveCount,
                      totalCount: jobs.length,
                      isAdmin: isAdmin,
                      onRefresh: () => ref.invalidate(myJobsProvider),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Chips(
                      selected: _filter,
                      counts: counts,
                      onSelect: (k) => setState(() => _filter = k),
                    ),
                  ),
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final g = groups[i];
                            return _TimelineGroup(
                              title: g.title,
                              jobs: g.jobs,
                              printerById: printerById,
                              pulse: _pulse,
                            );
                          },
                          childCount: groups.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<_DaySection> _groupByDay(List<Job> jobs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime keyOf(Job j) => j.endedAt ?? j.startedAt ?? j.submittedAt;

    final sorted = [...jobs]..sort((a, b) => keyOf(b).compareTo(keyOf(a)));

    final t = <Job>[], y = <Job>[], e = <Job>[];
    for (final j in sorted) {
      final d = keyOf(j);
      final day = DateTime(d.year, d.month, d.day);
      if (day == today) {
        t.add(j);
      } else if (day == yesterday) {
        y.add(j);
      } else {
        e.add(j);
      }
    }
    return [
      if (t.isNotEmpty) _DaySection('TODAY', t),
      if (y.isNotEmpty) _DaySection('YESTERDAY', y),
      if (e.isNotEmpty) _DaySection('EARLIER', e),
    ];
  }
}

class _DaySection {
  final String title;
  final List<Job> jobs;
  const _DaySection(this.title, this.jobs);
}

class _Header extends StatelessWidget {
  final int liveCount;
  final int totalCount;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _Header({
    required this.liveCount,
    required this.totalCount,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jobs',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.7,
                    height: 1.1,
                    color: _T.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _T.muted,
                    ),
                    children: [
                      TextSpan(
                        text: '● $liveCount live',
                        style: const TextStyle(
                          color: _T.violet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: ' · $totalCount total'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(Icons.search_rounded, _T.body, () {}),
          const SizedBox(width: 8),
          _iconBtn(Icons.refresh_rounded, _T.violet, onRefresh),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            Builder(
              builder: (ctx) => _iconBtn(
                Icons.admin_panel_settings_outlined,
                _T.violet,
                () => ctx.push(AppRoutes.jobAdmin),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color tint, VoidCallback onTap) {
    return Material(
      color: _T.card,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _T.border),
          ),
          child: Icon(icon, size: 16, color: tint),
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;
  const _Chips(
      {required this.selected,
      required this.counts,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, Color, Color)>[
      ('all', 'All', _T.ink, _T.borderSoft),
      ('printing', 'Active', _T.violet, _T.violetSoft),
      ('queued', 'Queued', _T.peach, _T.peachSoft),
      ('completed', 'Done', _T.mint, _T.mintSoft),
      ('cancelled', 'Failed', _T.coral, _T.coralSoft),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in items)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _Chip(
                  label: it.$2,
                  count: counts[it.$1] ?? 0,
                  color: it.$3,
                  soft: it.$4,
                  active: selected == it.$1,
                  onTap: () => onSelect(it.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color soft;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.color,
    required this.soft,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? soft : _T.card;
    final border = active ? color.withValues(alpha: 0.35) : _T.border;
    final fg = active ? color : _T.body;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.18)
                      : _T.borderSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: active ? color : _T.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineGroup extends StatelessWidget {
  final String title;
  final List<Job> jobs;
  final Map<String, Printer> printerById;
  final Animation<double> pulse;

  const _TimelineGroup({
    required this.title,
    required this.jobs,
    required this.printerById,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    color: _T.body,
                  ),
                ),
              ),
              Text(
                '${jobs.length} job${jobs.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                  color: _T.muted,
                ),
              ),
            ],
          ),
        ),
        // Rows (each row owns its own gutter + rail + dot + card)
        Column(
          children: [
            for (var i = 0; i < jobs.length; i++)
              _TimelineRow(
                job: jobs[i],
                printer: printerById[jobs[i].printerId],
                pulse: pulse,
                isFirst: i == 0,
                isLast: i == jobs.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Job job;
  final Printer? printer;
  final Animation<double> pulse;
  final bool isFirst;
  final bool isLast;

  const _TimelineRow({
    required this.job,
    required this.printer,
    required this.pulse,
    required this.isFirst,
    required this.isLast,
  });

  String _time() {
    final d = job.endedAt ?? job.startedAt ?? job.submittedAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    if (day == today || day == today.subtract(const Duration(days: 1))) {
      if (job.status == Job.queued || job.status == Job.scheduled) {
        return 'queued';
      }
      return '$hh:$mm';
    }
    const wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wk[d.weekday - 1]} $hh:$mm';
  }

  String _duration() {
    final s = job.actualDurationS ?? job.estimatedDurationS;
    if (s == null) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _meta() {
    final p = printer?.name ?? '—';
    final parts = <String>[p];
    if (job.status == Job.printing) {
      // live: just printer (progress shown separately)
    } else if (job.status == Job.queued || job.status == Job.scheduled) {
      parts.add('#${job.priority}');
    } else if (job.status == Job.canceled || job.status == Job.failed) {
      final err = job.errorMessage;
      if (err != null && err.isNotEmpty) parts.add(err);
    } else {
      final d = _duration();
      if (d.isNotEmpty) parts.add(d);
    }
    return parts.join(' · ');
  }

  String _liveLabel() {
    final pct = job.progressPct.clamp(0, 100).toStringAsFixed(0);
    int? secs = job.timeLeftSeconds;
    if (secs == null &&
        job.estimatedDurationS != null &&
        job.startedAt != null) {
      secs = job.estimatedDurationS! -
          DateTime.now().difference(job.startedAt!).inSeconds;
    }
    if (secs == null || secs <= 0) return '$pct%';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final eta = h > 0 ? '${h}h${m}m' : '${m}m';
    return '$pct% · $eta';
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(job.status);
    final isLive = job.status == Job.printing;
    final isError = job.status == Job.canceled || job.status == Job.failed;

    final card = Container(
              decoration: BoxDecoration(
                color: _T.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _T.borderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x05141428),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          job.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: _T.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: s.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _meta(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isError ? _T.coral : _T.body,
                    ),
                  ),
                  if (isLive) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: job.progressPct.clamp(0, 100) / 100,
                              minHeight: 5,
                              backgroundColor: _T.violetSoft,
                              valueColor: const AlwaysStoppedAnimation(
                                  _T.violet),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _liveLabel(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _T.violet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _T.violetSoft,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(Icons.pause_rounded,
                              size: 12, color: _T.violet),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );

    const dotSize = 18.0;
    const haloMax = 32.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/jobs/${job.id}', extra: job),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // time gutter
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 18, right: 10),
                child: Text(
                  _time(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _T.muted,
                  ),
                ),
              ),
            ),
            // card area with dot overlapping its left edge
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // rail: vertical 1px line running through dot center
                    // dot center sits at x = 0 (card's left edge)
                    Positioned(
                      left: -0.5,
                      top: isFirst ? 22 : -10,
                      bottom: isLast ? null : -10,
                      height: isLast ? 22 : null,
                      child: Container(width: 1, color: _T.border),
                    ),
                    // card (provides height; left padding leaves room for dot)
                    Padding(
                      padding: const EdgeInsets.only(left: dotSize / 2 + 4),
                      child: card,
                    ),
                    // pulsing halo (live only)
                    if (isLive)
                      Positioned(
                        left: -haloMax / 2,
                        top: 14 + dotSize / 2 - haloMax / 2,
                        width: haloMax,
                        height: haloMax,
                        child: AnimatedBuilder(
                          animation: pulse,
                          builder: (_, _) {
                            final v = pulse.value;
                            final size = dotSize + (haloMax - dotSize) * v;
                            return Center(
                              child: Opacity(
                                opacity: (0.55 * (1 - v)).clamp(0.0, 0.55),
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _T.violet, width: 1.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    // node — centered on card's left edge (x = 0)
                    Positioned(
                      left: -dotSize / 2,
                      top: 14,
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _T.card,
                          border: Border.all(color: s.dot, width: 2),
                        ),
                        child: Center(
                          child: isLive
                              ? Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: s.dot,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                color: _T.violetSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.print_outlined,
                color: _T.violet,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No jobs yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _T.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Submit a recommendation to get started',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _T.body),
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
          const Icon(Icons.error_outline_rounded, color: _T.coral, size: 40),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _T.body),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: _T.violet),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
