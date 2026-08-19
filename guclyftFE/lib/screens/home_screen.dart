import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'book_ride_screen.dart';
import 'schedule_ride_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatelessWidget {
  final String name;
  final String role;
  const HomeScreen({super.key, required this.name, required this.role});

  void _logout(BuildContext context) async {
    await ApiService.clearToken();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GUCLYFT"),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen(name: name))),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, $name 👋",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 30),
            _actionCard(
              context,
              icon: Icons.directions_car_filled_rounded,
              title: "Book a Ride",
              subtitle: "Request a ride now",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookRideScreen())),
            ),
            const SizedBox(height: 16),
            _actionCard(
              context,
              icon: Icons.calendar_month_rounded,
              title: "Schedule a Ride",
              subtitle: "Book for a future date/time",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleRideScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.blue),
          ],
        ),
      ),
    );
  }
}