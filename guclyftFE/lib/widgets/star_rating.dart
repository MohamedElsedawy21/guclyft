import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A row of tappable stars used to collect a 1-5 rating.
class StarRatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = starIndex <= value;
        return IconButton(
          onPressed: () => onChanged(starIndex),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? AppColors.yellow : AppColors.navy.withOpacity(0.25),
            size: size,
          ),
          splashRadius: size,
        );
      }),
    );
  }
}

/// A small, read-only row of stars used to display an existing rating.
class StarRatingDisplay extends StatelessWidget {
  final num value;
  final double size;

  const StarRatingDisplay({super.key, required this.value, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = (i + 1) <= value.round();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: filled ? AppColors.yellow : AppColors.navy.withOpacity(0.25),
          size: size,
        );
      }),
    );
  }
}