import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'view_gucians_screen.dart';
import 'medical_requests_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  final String name;
  const AdminHomeScreen({super.key, required this.name});

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
        title: const Text("GUCLYFT Admin"),
        actions: [
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
              icon: Icons.groups_rounded,
              title: "Registered Gucians",
              subtitle: "View all registered students & staff",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewGuciansScreen())),
            ),
            const SizedBox(height: 16),
                        _actionCard(
              context,
              icon: Icons.medical_information_outlined,
              title: "Medical Verification",
              subtitle: "Accept or reject disability/injury records",
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalRequestsScreen())),
            ),
            const SizedBox(height: 16),
            _actionCard(
              context,
              icon: Icons.star_rate_rounded,
              title: "Ride Feedback",
              subtitle: "Review ratings and feedback",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Coming soon")),
                );
              },
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