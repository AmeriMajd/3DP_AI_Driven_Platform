import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/printer.dart';
import 'printer_status_badge.dart';

class PrinterCard extends StatelessWidget {
  final Printer printer;
  final VoidCallback? onTap;

  const PrinterCard({super.key, required this.printer, this.onTap});

  IconData _technologyIcon() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return Icons.layers_outlined;
      case PrinterTechnology.sla:
        return Icons.opacity_outlined;
    }
  }

  String _technologyLabel() {
    switch (printer.technology) {
      case PrinterTechnology.fdm:
        return 'FDM';
      case PrinterTechnology.sla:
        return 'SLA';
    }
  }

  String _volumeLabel() {
    final x = printer.buildVolumeX;
    final y = printer.buildVolumeY;
    final z = printer.buildVolumeZ;
    if (x == null || y == null || z == null) {
      return 'Volume: —';
    }
    return 'Volume: ${x.toStringAsFixed(0)}×${y.toStringAsFixed(0)}×${z.toStringAsFixed(0)} mm';
  }

  String _materialsLabel() {
    final materials = printer.materialsSupported;
    if (materials == null || materials.isEmpty) {
      return 'Materials: —';
    }
    final preview = materials.take(3).join(', ');
    if (materials.length <= 3) {
      return 'Materials: $preview';
    }
    return 'Materials: $preview +${materials.length - 3}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _technologyIcon(),
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          printer.model ?? _technologyLabel(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PrinterStatusBadge(status: printer.status, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _volumeLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _materialsLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
