import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_log.dart';
import '../providers/activity_providers.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(activityViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityViewModelProvider);
    final vm = ref.read(activityViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Activity history'),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
      ),
      body: Column(
        children: [
          _FilterBar(filters: state.filters, onChanged: vm.setFilters),
          if (state.loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${state.error}'),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: vm.refresh,
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _ActivityTile(item: state.items[i]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final ActivityFilters filters;
  final ValueChanged<ActivityFilters> onChanged;

  const _FilterBar({required this.filters, required this.onChanged});

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: filters.dateFrom != null && filters.dateTo != null
          ? DateTimeRange(start: filters.dateFrom!, end: filters.dateTo!)
          : null,
    );
    if (picked != null) {
      onChanged(filters.copyWith(
        dateFrom: DateTime(picked.start.year, picked.start.month, picked.start.day),
        dateTo: DateTime(
          picked.end.year, picked.end.month, picked.end.day, 23, 59, 59,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickRange(context),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    filters.dateFrom == null
                        ? 'Any date'
                        : '${_fmt(filters.dateFrom!)} → ${_fmt(filters.dateTo!)}',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (filters.dateFrom != null)
                IconButton(
                  onPressed: () => onChanged(filters.copyWith(
                    clearDateFrom: true,
                    clearDateTo: true,
                  )),
                  icon: const Icon(Icons.clear, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: filters.eventType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ...kActivityEventTypes.map(
                      (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
                    ),
                  ],
                  onChanged: (v) => onChanged(
                    v == null
                        ? filters.copyWith(clearEventType: true)
                        : filters.copyWith(eventType: v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: filters.severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All')),
                    ...kActivitySeverities.map(
                      (s) => DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => onChanged(
                    v == null
                        ? filters.copyWith(clearSeverity: true)
                        : filters.copyWith(severity: v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ActivityTile extends StatelessWidget {
  final ActivityLog item;
  const _ActivityTile({required this.item});

  Color _severityColor() {
    switch (item.severity) {
      case 'error':
        return Colors.red.shade400;
      case 'warning':
        return Colors.orange.shade400;
      case 'success':
        return Colors.green.shade400;
      default:
        return Colors.blue.shade400;
    }
  }

  IconData _typeIcon() {
    switch (item.eventType) {
      case 'auth':
        return Icons.lock_outline;
      case 'job':
        return Icons.print_outlined;
      case 'printer':
        return Icons.precision_manufacturing_outlined;
      case 'file':
        return Icons.insert_drive_file_outlined;
      case 'notification':
        return Icons.notifications_outlined;
      case 'anomaly':
        return Icons.warning_amber_outlined;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = item.timestamp;
    final time =
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _severityColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon(), color: _severityColor(), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.message,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(item.eventType),
                    _chip(item.severity),
                    if (item.actorName != null) _chip(item.actorName!),
                    Text(time,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );
}
