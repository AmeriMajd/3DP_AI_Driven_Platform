import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/printer.dart';

class PrinterStatusBadge extends StatelessWidget {
  final PrinterStatusValue status;
  final bool compact;

  const PrinterStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  Color _backgroundColor() {
    switch (status) {
      case PrinterStatusValue.idle:
        return AppColors.success.withValues(alpha: 0.14);
      case PrinterStatusValue.printing:
        return const Color(0xFF2563EB).withValues(alpha: 0.14);
      case PrinterStatusValue.error:
        return AppColors.error.withValues(alpha: 0.14);
      case PrinterStatusValue.offline:
        return const Color(0xFF9CA3AF).withValues(alpha: 0.18);
      case PrinterStatusValue.maintenance:
        return AppColors.warning.withValues(alpha: 0.18);
    }
  }

  Color _textColor() {
    switch (status) {
      case PrinterStatusValue.idle:
        return AppColors.success;
      case PrinterStatusValue.printing:
        return const Color(0xFF2563EB);
      case PrinterStatusValue.error:
        return AppColors.error;
      case PrinterStatusValue.offline:
        return const Color(0xFF6B7280);
      case PrinterStatusValue.maintenance:
        return AppColors.warning;
    }
  }

  String _label() {
    switch (status) {
      case PrinterStatusValue.idle:
        return 'Idle';
      case PrinterStatusValue.printing:
        return 'Printing';
      case PrinterStatusValue.error:
        return 'Error';
      case PrinterStatusValue.offline:
        return 'Offline';
      case PrinterStatusValue.maintenance:
        return 'Maintenance';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _textColor().withValues(alpha: 0.4)),
      ),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: _textColor(),
        ),
      ),
    );
  }
}
