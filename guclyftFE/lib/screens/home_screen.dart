import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';
import '../services/ride_suggestion_engine.dart';
import '../widgets/campus_map.dart';
import '../widgets/suggested_trips_row.dart';
import '../services/send_item_service.dart';
import 'live_ride_screen.dart';

enum _Mode { book, schedule, sendItem }

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  _Mode _mode = _Mode.book;

  List<AppLocation> _locations = [];
  bool _loadingLocations = true;
  String? _loadError;

  int? _pickupId;
  int? _destinationId;
  int _passengerCount = 1;
  DateTime? _scheduledTime;
  final _itemDescController = TextEditingController();
  bool _checkingActiveRide = true;
  int? _activeRideId;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;
  List<TripSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _checkActiveRide();
    _loadLocations();
    _loadSuggestions();
  }

  Future<void> _checkActiveRide() async {
    try {
      final result = await RideService.getActiveRide();
      setState(() {
        _activeRideId = result['active'] == true ? result['ride_id'] : null;
        _checkingActiveRide = false;
      });
    } catch (_) {
      setState(() => _checkingActiveRide = false);
    }
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _loadError = null;
    });
    try {
      final locations = await LocationService.getLocations();
      setState(() => _locations = locations);
    } catch (e) {
      setState(() => _loadError = "Couldn't load locations.");
    } finally {
      setState(() => _loadingLocations = false);
    }
  }

  Future<void> _loadSuggestions() async {
    debugPrint("🔵 SUGGESTIONS: starting fetch...");
    try {
      final history = await RideService.getHistory();
      debugPrint("🔵 SUGGESTIONS: history fetched, ${history.length} trips");
      final suggestions = RideSuggestionEngine.suggest(history.cast<Map<String, dynamic>>());
      debugPrint("🔵 SUGGESTIONS: computed ${suggestions.length} suggestions");
      for (final s in suggestions) {
        debugPrint("🔵 SUGGESTIONS:   -> ${s.pickupName} -> ${s.destinationName} (score ${s.score})");
      }
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (e, st) {
      debugPrint("🔴 SUGGESTIONS: load failed: $e");
      debugPrint("$st");
    }
  }

  void _applySuggestion(TripSuggestion suggestion) {
    final pickup = _locations.where((l) => l.name == suggestion.pickupName).toList();
    final destination = _locations.where((l) => l.name == suggestion.destinationName).toList();
    if (pickup.isEmpty || destination.isEmpty) return;

    setState(() {
      _mode = _Mode.book;
      _pickupId = pickup.first.id;
      _destinationId = destination.first.id;
      _error = null;
    });
  }

  void _onPinTapped(AppLocation loc) {
    setState(() {
      // first tap sets pickup if empty, otherwise sets destination
      if (_pickupId == null) {
        _pickupId = loc.id;
      } else if (_destinationId == null && loc.id != _pickupId) {
        _destinationId = loc.id;
      } else {
        // both set already — tapping again reassigns destination
        _destinationId = loc.id == _pickupId ? _destinationId : loc.id;
      }
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(hours: 24)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() {
      _scheduledTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_pickupId == null || _destinationId == null) {
      setState(() => _error = "Please select pickup and destination");
      return;
    }
    if (_pickupId == _destinationId) {
      setState(() => _error = "Pickup and destination cannot be the same");
      return;
    }

        if (_mode == _Mode.sendItem) {
        if (_itemDescController.text.trim().isEmpty) {
          setState(() => _error = "Please describe the item");
          return;
        }
        setState(() {
          _submitting = true;
          _error = null;
        });
        try {
          final item = await SendItemService.create(
            pickupLocationId: _pickupId!,
            dropoffLocationId: _destinationId!,
            itemDescription: _itemDescController.text.trim(),
          );
          setState(() => _result = {"status": item.status, "id": item.id});
        } catch (e) {
          setState(() => _error = e.toString().replaceAll("Exception: ", ""));
        } finally {
          setState(() => _submitting = false);
        }
        return;
      }

    if (_mode == _Mode.schedule && _scheduledTime == null) {
      setState(() => _error = "Please select a date & time");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = _mode == _Mode.book
          ? await RideService.bookRide(
              pickupLocationId: _pickupId!,
              destinationLocationId: _destinationId!,
              passengerCount: _passengerCount,
            )
          : await RideService.scheduleRide(
              pickupLocationId: _pickupId!,
              destinationLocationId: _destinationId!,
              passengerCount: _passengerCount,
              scheduledTime: _scheduledTime!,
            );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => _submitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _pickupId = null;
      _destinationId = null;
      _passengerCount = 1;
      _scheduledTime = null;
      _itemDescController.clear();
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guclyft")),
      body: _checkingActiveRide
          ? const Center(child: CircularProgressIndicator())
          : _activeRideId != null
              ? LiveRideScreen(
                  rideId: _activeRideId!,
                  embedded: true,
                  onRideFinished: () => setState(() => _activeRideId = null),
                )
              : _loadingLocations
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!, style: const TextStyle(color: AppColors.error)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadLocations, child: const Text("Retry")),
                            ],
                          ),
                        )
                      : _result != null
                          ? _buildConfirmation()
                          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SuggestedTripsRow(suggestions: _suggestions, onTap: _applySuggestion),
        CampusMap(
          locations: _locations,
          pickupId: _pickupId,
          destinationId: _destinationId,
          onPinTapped: _onPinTapped,
        ),
        const SizedBox(height: 20),
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(value: _Mode.book, label: Text("Book")),
            ButtonSegment(value: _Mode.schedule, label: Text("Schedule")),
            ButtonSegment(value: _Mode.sendItem, label: Text("Send Item")),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
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

        if (_mode != _Mode.sendItem) ...[
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
          const SizedBox(height: 16),
        ],

        if (_mode == _Mode.schedule) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: AppColors.navy),
            title: Text(_scheduledTime == null
                ? "Select date & time"
                : "${_scheduledTime!.toLocal()}".substring(0, 16)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 16),
        ],

        if (_mode == _Mode.sendItem) ...[
          TextField(
            controller: _itemDescController,
            decoration: const InputDecoration(labelText: "Item Description", prefixIcon: Icon(Icons.inventory_2_outlined)),
          ),
          const SizedBox(height: 16),
        ],

        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
        ],

        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : Text(_mode == _Mode.book
                  ? "Confirm Booking"
                  : _mode == _Mode.schedule
                      ? "Confirm Schedule"
                      : "Send Item"),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 60),
          const SizedBox(height: 16),
                    Text(
            _mode == _Mode.book
                ? "Ride Booked!"
                : _mode == _Mode.schedule
                    ? "Ride Scheduled!"
                    : "Item Submitted!",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 20),
          Text("Status: ${_result!['status']}"),
          if (_mode == _Mode.book)
            Text("Verification Code: ${_result!['verification_code']}",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_mode == _Mode.schedule)
            Text("Scheduled for: ${_result!['scheduled_time']}"),
          const SizedBox(height: 24),
                   if (_mode != _Mode.sendItem) ...[
            ElevatedButton(
              onPressed: () => setState(() => _activeRideId = _result!['id']),
              child: const Text("Track My Ride"),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(onPressed: _resetForm, child: const Text("Book Another")),
        ],
      ),
    );
  }
}