import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/car_service.dart';
import '../services/location_service.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';

class CarHomeScreen extends StatefulWidget {
  final String name;
  const CarHomeScreen({super.key, required this.name});

  @override
  State<CarHomeScreen> createState() => _CarHomeScreenState();
}

class _CarHomeScreenState extends State<CarHomeScreen> {
  Timer? _pollTimer;
  Timer? _locationTimer;
  String _status = "idle";
  Map<String, dynamic>? _currentGroup;
  Map<int, String> _locationNames = {};
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  final Map<int, TextEditingController> _codeControllers = {};
  Set<int> _verifiedRideIds = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadLocationNames();
    await _loadCurrentStatus();
    _startPolling();
  }


  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required for live tracking")),
        );
      }
    }
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_status == "en_route" || _status == "in_progress") {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await CarService.updateLocation(position.latitude, position.longitude);
        } catch (_) {
          // silent — will retry on next tick
        }
      }
    });
  }

  Future<void> _loadLocationNames() async {
    try {
      final locations = await LocationService.getLocations();
      setState(() {
        _locationNames = {for (var l in locations) l.id: l.name};
      });
    } catch (_) {
      // non-fatal — falls back to showing raw IDs
    }
  }

    Future<void> _submitCode(int rideId) async {
    final controller = _codeControllers[rideId];
    if (controller == null || controller.text.trim().isEmpty) return;

    setState(() => _actionLoading = true);
    try {
      final result = await CarService.verifyCode(rideId, controller.text.trim());
      setState(() {
        _verifiedRideIds.add(rideId);
        if (result['all_verified'] == true) {
          _status = "in_progress";
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _loadCurrentStatus() async {
    setState(() => _loading = true);
    try {
      final result = await CarService.getCurrent();
      setState(() {
        _status = result['status'];
        _currentGroup = result['group_id'] != null ? result : null;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (_status == "idle") {
        await _checkForNextRide(silent: true);
      } else if (_status == "arrived") {
        await _checkGraceExpiry();
      }
    });
  }

  Future<void> _checkForNextRide({bool silent = false}) async {
    if (!silent) setState(() => _actionLoading = true);
    try {
      final result = await CarService.getNextRide();
      if (result['group_id'] != null) {
        setState(() {
          _status = "en_route";
          _currentGroup = result;
          _verifiedRideIds = {};
          _codeControllers.clear();
        });
      } else if (!silent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No rides in queue right now")),
          );
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      if (!silent) setState(() => _actionLoading = false);
    }
  }

  Future<void> _checkGraceExpiry() async {
    try {
      final status = await CarService.statusCheck();
      if (status != _status) {
        setState(() {
          _status = status;
          if (status == "idle") _currentGroup = null;
        });
      }
    } catch (_) {
      // silent — will retry next poll
    }
  }

  Future<void> _markArrived() async {
    setState(() => _actionLoading = true);
    try {
      await CarService.markArrived();
      setState(() => _status = "arrived");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeRide() async {
    setState(() => _actionLoading = true);
    try {
      await CarService.completeRide();
      setState(() {
        _status = "idle";
        _currentGroup = null;
      });
      // immediately check for the next ride instead of waiting for the next poll
      _checkForNextRide(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
        );
      }
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  void _logout() async {
    _pollTimer?.cancel();
    await ApiService.clearToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  String _locationName(dynamic id) {
    if (id == null) return "Unknown";
    return _locationNames[id] ?? "Location #$id";
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    for (var c in _codeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildStatusView(),
                ),
    );
  }

  Widget _buildStatusView() {
    switch (_status) {
      case "idle":
        return _buildIdleView();
      case "en_route":
        return _buildTripView(headerText: "En Route to Pickup", nextAction: "Mark Arrived", onAction: _markArrived);
      case "arrived":
        return _buildTripView(headerText: "Arrived — Waiting for Riders", nextAction: null, onAction: null);
      case "in_progress":
        return _buildTripView(headerText: "Trip In Progress", nextAction: "Complete Ride", onAction: _completeRide);
      default:
        return Center(child: Text("Status: $_status"));
    }
  }

  Widget _buildIdleView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_taxi_rounded, size: 70, color: AppColors.navy.withOpacity(0.3)),
        const SizedBox(height: 16),
        const Text("Idle — waiting for a ride", style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _actionLoading ? null : () => _checkForNextRide(),
          child: _actionLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text("Check for Ride"),
        ),
      ],
    );
  }

  Widget _buildTripView({required String headerText, String? nextAction, VoidCallback? onAction}) {
    final pickupId = _currentGroup?['pickup_location_id'];
    final destinationId = _currentGroup?['destination_location_id'];
    final passengerTotal = _currentGroup?['passenger_total'];
    final rideIds = _currentGroup?['ride_ids'] as List?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headerText, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.my_location, size: 18, color: AppColors.yellow),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Pickup: ${_locationName(pickupId)}")),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 18, color: AppColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Destination: ${_locationName(destinationId)}")),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, size: 18, color: AppColors.navy),
                  const SizedBox(width: 8),
                  Text("Passengers: ${passengerTotal ?? '-'}"),
                ],
              ),
              if (rideIds != null) ...[
                const SizedBox(height: 10),
                Text("Ride IDs: ${rideIds.join(', ')}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
        ),
                if (_status == "arrived" && rideIds != null) ...[
          const SizedBox(height: 20),
          const Text("Enter each rider's verification code:",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 10),
          ...rideIds.map((id) {
            final rideId = id as int;
            final isVerified = _verifiedRideIds.contains(rideId);
            _codeControllers.putIfAbsent(rideId, () => TextEditingController());
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeControllers[rideId],
                      enabled: !isVerified,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Ride #$rideId code",
                        suffixIcon: isVerified ? const Icon(Icons.check_circle, color: Colors.green) : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!isVerified)
                    ElevatedButton(
                      onPressed: _actionLoading ? null : () => _submitCode(rideId),
                      child: const Text("Verify"),
                    ),
                ],
              ),
            );
          }),
        ],
        const Spacer(),
        if (nextAction != null && onAction != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _actionLoading ? null : onAction,
              child: _actionLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text(nextAction),
            ),
          ),
      ],
    );
  }
}