import 'package:flutter/material.dart';

import 'dashboard_tokens.dart';

class FilterChipOption {
  final String key;
  final String label;
  final int? count;
  const FilterChipOption({required this.key, required this.label, this.count});
}

class DashFilterChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  final List<FilterChipOption> options;

  const DashFilterChips({
    super.key,
    required this.value,
    required this.onChange,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final opt = options[i];
          final active = opt.key == value;
          return GestureDetector(
            onTap: () => onChange(opt.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? DT.accentSoft : DT.surface1,
                border: Border.all(color: active ? DT.accent : DT.border),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    opt.label,
                    style: TextStyle(
                      color: active ? DT.accent : DT.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (opt.count != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      '${opt.count}',
                      style: TextStyle(
                        color: active ? DT.accent : DT.text2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
