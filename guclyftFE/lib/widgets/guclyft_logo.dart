import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GuclyftLogo extends StatelessWidget {
  final double size;
  const GuclyftLogo({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.directions_car_filled_rounded,
              color: Colors.white, size: size * 0.55),
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'GUC',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              TextSpan(
                text: 'LYFT',
                style: TextStyle(
                  color: AppColors.lightBlue,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}