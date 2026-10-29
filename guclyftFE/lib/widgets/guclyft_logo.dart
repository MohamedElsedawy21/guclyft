import 'package:flutter/material.dart';

class GuclyftLogo extends StatelessWidget {
  final double size;
  const GuclyftLogo({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/guclyft_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }
}