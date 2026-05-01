import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/responsive_wrapper.dart';
import '../../domain/printer.dart';
import '../../domain/printer_status.dart';
import '../../providers/printer_providers.dart';
import '../widgets/printer_status_badge.dart';

class PrinterDetailScreen extends ConsumerWidget {
  final String printerId;

  const PrinterDetailScreen({super.key, required this.printerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerAsync = ref.watch(printerDetailProvider(printerId));
    final statusAsync = ref.watch(printerStatusProvider(printerId));
    final isAdmin = ref.watch(isAdminProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Printer Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.textPrimary,
              ),
              onPressed: () => context.go('${AppRoutes.fleet}/$printerId/edit'),
            ),
        ],
      ),
      body: printerAsync.when(
        data: (printer) => _DetailBody(
          printer: printer,
          statusAsync: statusAsync,
          isAdmin: isAdmin,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Printer printer;
  final AsyncValue<PrinterStatus> statusAsync;
  final bool isAdmin;

  const _DetailBody({
    required this.printer,
    required this.statusAsync,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStatus = statusAsync.asData?.value;
    final statusValue = liveStatus?.status ?? printer.status;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: ResponsiveWrapper(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(statusValue),
            const SizedBox(height: 16),
            _buildMetrics(liveStatus),
            const SizedBox(height: 16),
            _buildSpecs(),
            const SizedBox(height: 16),
            _buildMaterials(),
            const SizedBox(height: 16),
            _buildConnection(context, ref),
            if (isAdmin) ...[
              const SizedBox(height: 20),
              _buildAdminActions(context, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PrinterStatusValue statusValue) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                printer.technology == PrinterTechnology.fdm
                    ? Icons.layers_outlined
                    : Icons.opacity_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    printer.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    printer.model ?? _technologyLabel(printer.technology),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrinterStatusBadge(status: statusValue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(PrinterStatus? liveStatus) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Metrics',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _metricTile(
                  label: 'Current Job',
                  value: liveStatus?.currentJobId ?? '—',
                ),
                _metricTile(
                  label: 'Progress',
                  value: liveStatus?.progressPct == null
                      ? '—'
                      : '${liveStatus!.progressPct!.toStringAsFixed(0)}%',
                ),
                _metricTile(
                  label: 'Nozzle',
                  value: liveStatus?.temperatureNozzle == null
                      ? '—'
                      : '${liveStatus!.temperatureNozzle!.toStringAsFixed(0)}°C',
                ),
                _metricTile(
                  label: 'Bed',
                  value: liveStatus?.temperatureBed == null
                      ? '—'
                      : '${liveStatus!.temperatureBed!.toStringAsFixed(0)}°C',
                ),
                _metricTile(
                  label: 'Last Seen',
                  value: _formatDate(liveStatus?.lastSeenAt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecs() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Build Volume',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _buildVolume(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterials() {
    final materials = printer.materialsSupported ?? [];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materials',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (materials.isEmpty)
              const Text(
                'No materials configured yet.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: materials
                    .map(
                      (material) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          material,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnection(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Connection',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _testConnection(context, ref),
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: const Text('Test'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow('Connector', _connectorLabel(printer.connectorType)),
            _infoRow(
              'Connection URL',
              'Hidden — re-enter to update in edit mode',
            ),
            _infoRow('API Key', 'Stored securely (never shown)'),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                context.go('${AppRoutes.fleet}/${printer.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ),
      ],
    );
  }

  Widget _metricTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(printerRepositoryProvider);
      final result = await repo.testPrinter(id: printer.id);
      _showSnack(context, result.message, AppColors.success);
    } catch (error) {
      _showSnack(context, _readableError(error), AppColors.error);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete printer?'),
        content: const Text(
          'This will remove the printer from your fleet. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(printerRepositoryProvider);
      await repo.deletePrinter(id: printer.id);
      ref.invalidate(printersListProvider);
      if (context.mounted) {
        _showSnack(context, 'Printer deleted', AppColors.success);
        context.go(AppRoutes.fleet);
      }
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, _readableError(error), AppColors.error);
      }
    }
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _buildVolume() {
    final x = printer.buildVolumeX;
    final y = printer.buildVolumeY;
    final z = printer.buildVolumeZ;
    if (x == null || y == null || z == null) {
      return 'Not specified';
    }
    return '${x.toStringAsFixed(0)} × ${y.toStringAsFixed(0)} × ${z.toStringAsFixed(0)} mm';
  }

  String _technologyLabel(PrinterTechnology tech) {
    switch (tech) {
      case PrinterTechnology.fdm:
        return 'FDM';
      case PrinterTechnology.sla:
        return 'SLA';
    }
  }

  String _connectorLabel(PrinterConnectorType connector) {
    switch (connector) {
      case PrinterConnectorType.octoprint:
        return 'OctoPrint';
      case PrinterConnectorType.prusalink:
        return 'PrusaLink';
      case PrinterConnectorType.mock:
        return 'Mock';
      case PrinterConnectorType.manual:
        return 'Manual';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _readableError(Object error) {
    final text = error.toString();
    return text.replaceFirst('Exception: ', '');
  }
}
