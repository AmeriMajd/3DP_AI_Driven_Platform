import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';

class TimeRangeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final List<String> options;
  const TimeRangeSelector({
    super.key,
    required this.value,
    required this.onChange,
    this.options = const ['7d', '30d', '90d', 'all'],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DT.surface2,
        border: Border.all(color: DT.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final active = opt == value;
          return GestureDetector(
            onTap: () => onChange(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active ? DT.surface1 : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active ? DT.shadowSm : null,
              ),
              child: Text(
                opt == 'all' ? 'All' : opt,
                style: TextStyle(
                  color: active ? DT.text : DT.text3,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
