import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// 5-star rating widget with local optimistic update.
/// Calls [onRate] with the tapped star index (1–5).
class StarRatingWidget extends StatefulWidget {
  final int? currentRating;
  final Future<void> Function(int rating) onRate;

  const StarRatingWidget({
    super.key,
    this.currentRating,
    required this.onRate,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget> {
  int? _localRating;
  bool _isSubmitting = false;

  int? get _displayRating => _localRating ?? widget.currentRating;

  Future<void> _handleTap(int rating, BuildContext context) async {
    if (_isSubmitting) return;
    // Capture ScaffoldMessenger before any async gap to avoid
    // "looking up a deactivated widget's ancestor" errors.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _localRating = rating;
      _isSubmitting = true;
    });
    try {
      await widget.onRate(rating);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Revert on failure
      if (mounted) setState(() => _localRating = null);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Rate this recommendation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled =
                _displayRating != null && starIndex <= _displayRating!;
            return IconButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _handleTap(starIndex, context),
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? AppColors.warning : AppColors.textSecondary,
                size: 36,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
            );
          }),
        ),
        if (_displayRating != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$_displayRating / 5',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
