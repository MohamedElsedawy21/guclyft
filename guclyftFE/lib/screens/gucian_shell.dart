import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'past_trips_tab.dart';
import 'account_screen.dart';

class GucianShell extends StatefulWidget {
  final String name;
  const GucianShell({super.key, required this.name});

  @override
  State<GucianShell> createState() => _GucianShellState();
}

class _GucianShellState extends State<GucianShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const HomeTab(),
      const PastTripsTab(),
      AccountScreen(name: widget.name),
    ];

    return Scaffold(
      body: tabs[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: "Past Trips"),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), activeIcon: Icon(Icons.account_circle), label: "Account"),
        ],
      ),
    );
  }
}