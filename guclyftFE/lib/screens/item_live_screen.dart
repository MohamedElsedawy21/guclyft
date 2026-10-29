import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/send_item_service.dart';
import '../widgets/campus_map.dart';

class ItemLiveScreen extends StatefulWidget {
  final int itemId;
  final bool embedded;
  final VoidCallback? onFinished;

  const ItemLiveScreen({
    super.key,
    required this.itemId,
    this.embedded = false,
    this.onFinished,
  });

  @override
  State<ItemLiveScreen> createState() => _ItemLiveScreenState();
}

class _ItemLiveScreenState extends State<ItemLiveScreen> {
  Timer? _pollTimer;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 7), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final data = await SendItemService.getLiveStatus(widget.itemId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
      });
      if (data['status'] == "delivered" || data['status'] == "cancelled") {
        _pollTimer?.cancel();
        widget.onFinished?.call();
      }
    } catch (e) {
      if (mounted) setState(() { _error = "Couldn't load item status"; _loading = false; });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
      appBar: AppBar(title: const Text("Item Tracking")),
      body: body,
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final status = data['status'];
    final pickup = data['pickup'];
    final dropoff = data['dropoff'];
    final car = data['car'];
    final path = (data['path'] as List?)?.map((p) => [p[0] as double, p[1] as double]).toList();

    final pins = <MapPin>[];
    if (pickup != null) pins.add(MapPin(lat: pickup['lat'], lng: pickup['lng'], color: AppColors.yellow, icon: Icons.my_location));
    if (dropoff != null) pins.add(MapPin(lat: dropoff['lat'], lng: dropoff['lng'], color: AppColors.red, icon: Icons.flag));
    if (car != null) pins.add(MapPin(lat: car['lat'], lng: car['lng'], color: AppColors.navy, icon: Icons.local_taxi_rounded, size: 34));

    String title;
    IconData icon;
    switch (status) {
      case "queued":
        title = "Waiting for a car to be assigned";
        icon = Icons.hourglass_empty_rounded;
        break;
      case "in_transit":
        title = "Item is on its way";
        icon = Icons.local_shipping_rounded;
        break;
      case "delivered":
        title = "Item delivered!";
        icon = Icons.check_circle_outline;
        break;
      case "cancelled":
        title = "Item request cancelled";
        icon = Icons.cancel_outlined;
        break;
      default:
        title = "Status: $status";
        icon = Icons.info_outline;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CampusMap(path: path, extraPins: pins, height: 260),
        const SizedBox(height: 20),
        Container(
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
              const SizedBox(height: 8),
              Text(data['item_description'] ?? "", style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}