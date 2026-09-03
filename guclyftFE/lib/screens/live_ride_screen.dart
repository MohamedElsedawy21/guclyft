import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ride_service.dart';
import '../services/rating_service.dart';
import '../widgets/campus_map.dart';
import '../widgets/rate_ride_sheet.dart';
import '../widgets/star_rating.dart';

class LiveRideScreen extends StatefulWidget {
  final int rideId;
  final bool embedded;
  final VoidCallback? onRideFinished;

  const LiveRideScreen({
    super.key,
    required this.rideId,
    this.embedded = false,
    this.onRideFinished,
  });


  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen> {
  Timer? _pollTimer;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _cancelling = false;

  String? _error;

  Map<String, dynamic>? _rating;
  bool _ratingLoading = false;
  bool _ratingChecked = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 7), (_) => _fetch());
  }
    Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("Are you sure you want to cancel this ride?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Cancel")),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await RideService.cancelRide(widget.rideId);
      _pollTimer?.cancel();
      widget.onRideFinished?.call();
      if (!widget.embedded && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
  Future<void> _checkRating() async {
    _ratingChecked = true;
    setState(() => _ratingLoading = true);
    try {
      final rating = await RatingService.getRating(widget.rideId);
      if (mounted) setState(() => _rating = rating);
    } catch (_) {
      // silently ignore — rating prompt just won't show pre-filled
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
  }

  Future<void> _openRateSheet() async {
    final result = await showRateRideSheet(context, widget.rideId);
    if (result != null && mounted) {
      setState(() => _rating = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thanks for rating your ride!")),
      );
    }
  }

  Future<void> _fetch() async {
    try {
      final data = await RideService.getLiveStatus(widget.rideId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });

      final status = data['status'];
      if (status == "no_show") {
        widget.onRideFinished?.call();
        _pollTimer?.cancel();
      } else if (status == "completed") {
        if (!_ratingChecked) _checkRating();
        final exitSeconds = _secondsLeft(data['departure_deadline']);
        if (exitSeconds != null && exitSeconds <= 0) {
          widget.onRideFinished?.call();
          _pollTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Couldn't load ride status";
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  int? _secondsLeft(String? isoTime) {
    if (isoTime == null) return null;
    final target = DateTime.parse(isoTime);
    final targetUtc = target.isUtc ? target : target.toUtc();
    final diff = targetUtc.difference(DateTime.now().toUtc()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
            : _buildContent();

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Your Ride")),
      body: body,
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final status = data['status'];
    final pickup = data['pickup'];
    final destination = data['destination'];
    final car = data['car'];
    final path = (data['path'] as List?)?.map((p) => [p[0] as double, p[1] as double]).toList();
    final etaMinutes = data['eta_minutes'];

    final pins = <MapPin>[];
    if (pickup != null) {
      pins.add(MapPin(lat: pickup['lat'], lng: pickup['lng'], color: AppColors.yellow, icon: Icons.my_location));
    }
    if (destination != null) {
      pins.add(MapPin(lat: destination['lat'], lng: destination['lng'], color: AppColors.red, icon: Icons.flag));
    }
    if (car != null) {
      pins.add(MapPin(lat: car['lat'], lng: car['lng'], color: AppColors.navy, icon: Icons.local_taxi_rounded, size: 34));
    }

        return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CampusMap(path: path, extraPins: pins, height: 260),
        const SizedBox(height: 20),
        _buildStatusCard(status, etaMinutes, data),
        if (status == "queued" || status == "en_route") ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelling ? null : _cancelRide,
              icon: _cancelling
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.close, color: AppColors.error),
              label: Text(_cancelling ? "Cancelling..." : "Cancel Ride", style: const TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusCard(String status, dynamic etaMinutes, Map<String, dynamic> data) {
    switch (status) {
      case "queued":
        return _card(
          icon: Icons.hourglass_empty_rounded,
          title: "Waiting for a car to be assigned",
          subtitle: "You're in the queue — hang tight!",
        );
      case "en_route":
        return _card(
          icon: Icons.local_taxi_rounded,
          title: "Car on its way",
          subtitle: etaMinutes != null ? "ETA: ${etaMinutes.toStringAsFixed(0)} min" : "Calculating ETA...",
        );
      case "arrived":
        final graceSeconds = _secondsLeft(data['grace_expires_at']);
        return _card(
          icon: Icons.check_circle_outline,
          title: "Car has arrived!",
          subtitle: graceSeconds != null ? "Time left: ${graceSeconds}s" : null,
          extra: Column(
            children: [
              const SizedBox(height: 12),
              const Text("Give this code to the driver:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
              Text(
                data['verification_code'] ?? "----",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.navy, letterSpacing: 4),
              ),
            ],
          ),
        );
      case "in_progress":
        return _card(
          icon: Icons.route_rounded,
          title: "Ride in progress",
          subtitle: etaMinutes != null ? "ETA to destination: ${etaMinutes.toStringAsFixed(0)} min" : null,
        );
      case "completed":
        final exitSeconds = _secondsLeft(data['departure_deadline']);
        return _card(
          icon: Icons.flag_circle_rounded,
          title: "You have arrived!",
          subtitle: exitSeconds != null && exitSeconds > 0
              ? "Please exit within: ${exitSeconds}s"
              : "Thanks for riding with Guclyft!",
          extra: _buildRatingSection(),
        );
      case "no_show":
        return _card(
          icon: Icons.cancel_outlined,
          title: "Marked as no-show",
          subtitle: "The grace period expired before you boarded.",
        );
      default:
        return _card(icon: Icons.info_outline, title: "Status: $status");
    }
  }

  Widget _buildRatingSection() {
    if (_ratingLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_rating != null) {
      final stars = _rating!['stars'] as num;
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            const Text("Your rating", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            StarRatingDisplay(value: stars, size: 22),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openRateSheet,
          icon: const Icon(Icons.star_rounded, color: AppColors.black),
          label: const Text("Rate this ride"),
        ),
      ),
    );
  }

  Widget _card({required IconData icon, required String title, String? subtitle, Widget? extra}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.yellow),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy), textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          ],
          if (extra != null) extra,
        ],
      ),
    );
  }
}