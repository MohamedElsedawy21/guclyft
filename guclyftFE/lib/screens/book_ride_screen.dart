import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  List<AppLocation> _locations = [];
  bool _loadingLocations = true;
  String? _loadError;

  int? _pickupId;
  int? _destinationId;
  int _passengerCount = 1;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await LocationService.getLocations();
      setState(() {
        _locations = locations;
        _loadingLocations = false;
      });
    } catch (e) {
      setState(() {
        _loadError = "Couldn't load locations. Pull to retry.";
        _loadingLocations = false;
      });
    }
  }

  Future<void> _book() async {
    if (_pickupId == null || _destinationId == null) {
      setState(() => _error = "Please select pickup and destination");
      return;
    }
    if (_pickupId == _destinationId) {
      setState(() => _error = "Pickup and destination cannot be the same");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await RideService.bookRide(
        pickupLocationId: _pickupId!,
        destinationLocationId: _destinationId!,
        passengerCount: _passengerCount,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Book a Ride")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingLocations) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _loadingLocations = true);
                _loadLocations();
              },
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }
    return _result != null ? _buildConfirmation() : _buildForm();
  }

  Widget _buildForm() {
    return ListView(
      children: [
        DropdownButtonFormField<int>(
          initialValue: _pickupId,
          decoration: const InputDecoration(labelText: "Pickup Point", prefixIcon: Icon(Icons.my_location)),
          items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => _pickupId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _destinationId,
          decoration: const InputDecoration(labelText: "Destination", prefixIcon: Icon(Icons.flag_outlined)),
          items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
          onChanged: (v) => setState(() => _destinationId = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text("Passengers:", style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: _passengerCount > 1 ? () => setState(() => _passengerCount--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text("$_passengerCount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              onPressed: _passengerCount < 4 ? () => setState(() => _passengerCount++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loading ? null : _book,
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("Confirm Booking"),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 60),
        const SizedBox(height: 16),
        const Text("Ride Booked!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 20),
        Text("Status: ${_result!['status']}"),
        Text("Verification Code: ${_result!['verification_code']}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Back to Home"),
        ),
      ],
    );
  }
}