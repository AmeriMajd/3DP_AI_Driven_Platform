import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// 5-star rating widget with local optimistic update.
/// Stars are permanently disabled once a rating is submitted or if
/// [currentRating] is already set from the server.
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
  /// Non-null once the user has tapped a star in this session.
  int? _localRating;
  bool _isSubmitting = false;

  /// The rating to display: local optimistic → server value → nothing.
  int? get _displayRating => _localRating ?? widget.currentRating;

  /// True once rated (either this session or from the server).
  bool get _alreadyRated => _displayRating != null;

  Future<void> _handleTap(int rating, BuildContext context) async {
    if (_isSubmitting || _alreadyRated) return;

    // Capture messenger before any async gap.
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _localRating = rating;
      _isSubmitting = true;
    });

    try {
      await widget.onRate(rating);
      // Success — stars stay disabled, inline message appears.
    } catch (_) {
      // Revert optimistic update so user can try again.
      if (mounted) {
        setState(() => _localRating = null);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not save rating. Please try again.'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _alreadyRated ? 'Thanks for your feedback!' : 'Rate this recommendation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _alreadyRated
                ? AppColors.success
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled =
                _displayRating != null && starIndex <= _displayRating!;
            final interactive = !_isSubmitting && !_alreadyRated;

            return IconButton(
              onPressed: interactive
                  ? () => _handleTap(starIndex, context)
                  : null,
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled
                    ? AppColors.warning
                    : (_alreadyRated
                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                        : AppColors.textSecondary),
                size: 36,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
            );
          }),
        ),
        if (_isSubmitting)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.warning,
              ),
            ),
          ),
        if (_alreadyRated && !_isSubmitting)
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
