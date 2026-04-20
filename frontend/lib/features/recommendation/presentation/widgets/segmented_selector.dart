import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Generic segmented control row — active option gets the primary colour fill.
class SegmentedSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final void Function(String) onSelect;
  final String Function(String)? labelBuilder;

  const SegmentedSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.asMap().entries.map((entry) {
        final idx = entry.key;
        final opt = entry.value;
        final isSelected = opt == selected;
        final label = labelBuilder != null ? labelBuilder!(opt) : opt;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                left: idx == 0 ? 0 : 4,
                right: idx == options.length - 1 ? 0 : 4,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.textLight
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
