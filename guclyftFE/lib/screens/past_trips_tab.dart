import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ride_service.dart';
import '../widgets/rate_ride_sheet.dart';
import '../widgets/star_rating.dart';

class PastTripsTab extends StatefulWidget {
  const PastTripsTab({super.key});

  @override
  State<PastTripsTab> createState() => _PastTripsTabState();
}

class _PastTripsTabState extends State<PastTripsTab> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await RideService.getHistory();
      setState(() => _trips = trips.cast<Map<String, dynamic>>());
    } catch (e) {
      setState(() => _error = "Couldn't load past trips. Pull to retry.");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _rate(Map<String, dynamic> trip) async {
    final result = await showRateRideSheet(context, trip['ride_id']);
    if (result != null && mounted) {
      setState(() => trip['rating'] = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks for rating your ride!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Past Trips")),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(_error!, style: const TextStyle(color: AppColors.error))),
        ],
      );
    }
    if (_trips.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Column(
            children: [
              Icon(Icons.history_rounded, size: 60, color: AppColors.navy.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text("No trips yet", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, i) => _tripCard(_trips[i]),
    );
  }

  Widget _tripCard(Map<String, dynamic> trip) {
    final status = trip['status'] as String;
    final rating = trip['rating'] as Map<String, dynamic>?;
    final createdAt = DateTime.tryParse(trip['created_at'] ?? '')?.toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatDateTime(createdAt),
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _statusPill(status),
            ],
          ),
          const SizedBox(height: 12),
          _routeRow(trip['pickup_name'] ?? '—', trip['destination_name'] ?? '—'),
          if (status == "completed") ...[
            const Divider(height: 28),
            _ratingRow(trip, rating),
          ],
        ],
      ),
    );
  }

  Widget _routeRow(String pickup, String destination) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.my_location, size: 16, color: AppColors.yellow),
            Container(
              width: 2,
              height: 24,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: AppColors.navy.withOpacity(0.15),
            ),
            const Icon(Icons.flag, size: 16, color: AppColors.red),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy)),
              const SizedBox(height: 24),
              Text(destination, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingRow(Map<String, dynamic> trip, Map<String, dynamic>? rating) {
    if (rating != null) {
      return Row(
        children: [
          const Text("Your rating", style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 8),
          StarRatingDisplay(value: rating['stars'] as num, size: 18),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _rate(trip),
        icon: const Icon(Icons.star_border_rounded, size: 18),
        label: const Text("Rate this ride"),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          side: BorderSide(color: AppColors.navy.withOpacity(0.2)),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    Color color;
    String label;
    switch (status) {
      case "completed":
        color = AppColors.yellow;
        label = "Completed";
        break;
      case "cancelled":
        color = AppColors.error;
        label = "Cancelled";
        break;
      case "no_show":
        color = Colors.grey;
        label = "No-show";
        break;
      default:
        color = AppColors.navy;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color == AppColors.yellow ? const Color(0xFF8A6D00) : color),
      ),
    );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "—";
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? "AM" : "PM";
    final minute = dt.minute.toString().padLeft(2, '0');
    return "${months[dt.month - 1]} ${dt.day}, $hour12:$minute $ampm";
  }
}