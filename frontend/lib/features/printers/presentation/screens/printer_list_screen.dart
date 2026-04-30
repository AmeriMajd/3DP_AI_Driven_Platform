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
    final filter = PrinterFilter(technology: _technology, status: _status);
    final printersAsync = ref.watch(printersListProvider(filter));
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.printerNew),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Printer'),
            )
          : null,
      body: SafeArea(
        child: ResponsiveWrapper(
          maxWidth: 920,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 12),
              Expanded(
                child: printersAsync.when(
                  data: (printers) => _buildList(printers),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(printersListProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Fleet Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Track printer availability and readiness at a glance.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: 'All Tech',
                selected: _technology == null,
                onSelected: () => setState(() => _technology = null),
              ),
              _filterChip(
                label: 'FDM',
                selected: _technology == PrinterTechnology.fdm,
                onSelected: () =>
                    setState(() => _technology = PrinterTechnology.fdm),
              ),
              _filterChip(
                label: 'SLA',
                selected: _technology == PrinterTechnology.sla,
                onSelected: () =>
                    setState(() => _technology = PrinterTechnology.sla),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: 'All Status',
                selected: _status == null,
                onSelected: () => setState(() => _status = null),
              ),
              _filterChip(
                label: 'Idle',
                selected: _status == PrinterStatusValue.idle,
                onSelected: () =>
                    setState(() => _status = PrinterStatusValue.idle),
              ),
              _filterChip(
                label: 'Printing',
                selected: _status == PrinterStatusValue.printing,
                onSelected: () =>
                    setState(() => _status = PrinterStatusValue.printing),
              ),
              _filterChip(
                label: 'Offline',
                selected: _status == PrinterStatusValue.offline,
                onSelected: () =>
                    setState(() => _status = PrinterStatusValue.offline),
              ),
              _filterChip(
                label: 'Maintenance',
                selected: _status == PrinterStatusValue.maintenance,
                onSelected: () =>
                    setState(() => _status = PrinterStatusValue.maintenance),
              ),
              _filterChip(
                label: 'Error',
                selected: _status == PrinterStatusValue.error,
                onSelected: () =>
                    setState(() => _status = PrinterStatusValue.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.borderLight,
      ),
    );
  }

  Widget _buildList(List<Printer> printers) {
    if (printers.isEmpty) {
      return const _EmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(printersListProvider);
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: printers.length,
            itemBuilder: (context, index) {
              final printer = printers[index];
              return PrinterCard(
                printer: printer,
                onTap: () => context.go('${AppRoutes.fleet}/${printer.id}'),
              );
            },
          ),
        );
      },
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
              'No printers yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Add your first printer to start building the fleet.',
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
