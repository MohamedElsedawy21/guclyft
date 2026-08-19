import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const GuclyftApp());
}

class GuclyftApp extends StatelessWidget {
  const GuclyftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUCLYFT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}