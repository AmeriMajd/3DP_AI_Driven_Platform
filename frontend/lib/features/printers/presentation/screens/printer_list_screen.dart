import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_wrapper.dart';
import '../../domain/printer.dart';
import '../../domain/printer_filter.dart';
import '../../providers/printer_providers.dart';
import '../widgets/printer_card.dart';

class PrinterListScreen extends ConsumerStatefulWidget {
  const PrinterListScreen({super.key});

  @override
  ConsumerState<PrinterListScreen> createState() => _PrinterListScreenState();
}

class _PrinterListScreenState extends ConsumerState<PrinterListScreen> {
  PrinterTechnology? _technology;
  PrinterStatusValue? _status;

  @override
  Widget build(BuildContext context) {
    // Always fetch full list; filter client-side so counts stay accurate.
    final printersAsync = ref.watch(
      printersListProvider(const PrinterFilter()),
    );
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.printerNew),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add printer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: SafeArea(
        child: ResponsiveWrapper(
          maxWidth: 920,
          child: printersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(printersListProvider),
            ),
            data: (all) {
              final byTech = _technology == null
                  ? all
                  : all.where((p) => p.technology == _technology).toList();
              final filtered = _status == null
                  ? byTech
                  : byTech.where((p) => p.status == _status).toList();
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(printersListProvider),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildStatCards(all)),
                    SliverToBoxAdapter(child: _buildTechTabs()),
                    SliverToBoxAdapter(child: _buildStatusChips(byTech)),
                    if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.crossAxisExtent;
                            final crossAxisCount =
                                w >= 900 ? 3 : w >= 600 ? 2 : 1;
                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 160,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final p = filtered[i];
                                  return PrinterCard(
                                    printer: p,
                                    onTap: () => context
                                        .go('${AppRoutes.fleet}/${p.id}'),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(List<Printer> all) {
    int countWhere(bool Function(Printer) f) => all.where(f).length;
    final ready = countWhere((p) => p.status == PrinterStatusValue.idle);
    final active = countWhere((p) => p.status == PrinterStatusValue.printing);
    final issues = countWhere((p) =>
        p.status == PrinterStatusValue.error ||
        p.status == PrinterStatusValue.maintenance);
    final offline = countWhere((p) => p.status == PrinterStatusValue.offline);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _statCard('Ready', ready, AppColors.success, const Color(0xFFECFDF5)),
          const SizedBox(width: 8),
          _statCard('Active', active, AppColors.primary,
              const Color(0xFFEDE9FE)),
          const SizedBox(width: 8),
          _statCard('Issues', issues, AppColors.error, const Color(0xFFFEF2F2)),
          const SizedBox(width: 8),
          _statCard('Offline', offline, const Color(0xFF6B7280),
              const Color(0xFFF3F4F6)),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color dot, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            _techTab('All technologies', null),
            _techTab('FDM', PrinterTechnology.fdm),
            _techTab('SLA', PrinterTechnology.sla),
          ],
        ),
      ),
    );
  }

  Widget _techTab(String label, PrinterTechnology? tech) {
    final selected = _technology == tech;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _technology = tech),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChips(List<Printer> byTech) {
    int n(PrinterStatusValue? s) =>
        s == null ? byTech.length : byTech.where((p) => p.status == s).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statusChip('All', null, n(null)),
            _statusChip('Printing', PrinterStatusValue.printing,
                n(PrinterStatusValue.printing)),
            _statusChip(
                'Idle', PrinterStatusValue.idle, n(PrinterStatusValue.idle)),
            _statusChip(
                'Error', PrinterStatusValue.error, n(PrinterStatusValue.error)),
            _statusChip('Offline', PrinterStatusValue.offline,
                n(PrinterStatusValue.offline)),
            _statusChip('Maintenance', PrinterStatusValue.maintenance,
                n(PrinterStatusValue.maintenance)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, PrinterStatusValue? value, int count) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.cardLight,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.precision_manufacturing_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12),
            Text(
              'No printers match',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Adjust filters or add a printer to the fleet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'Could not load printers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
