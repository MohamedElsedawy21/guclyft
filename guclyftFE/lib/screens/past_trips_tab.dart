import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PastTripsTab extends StatelessWidget {
  const PastTripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Past Trips")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 60, color: AppColors.navy.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text("No trips yet", style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}