import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

class CampusMap extends StatelessWidget {
  final List<AppLocation> locations;
  final int? pickupId;
  final int? destinationId;
  final void Function(AppLocation) onPinTapped;
  final double height;

  const CampusMap({
    super.key,
    required this.locations,
    required this.pickupId,
    required this.destinationId,
    required this.onPinTapped,
    this.height = 220,
  });

  LatLng get _center {
    if (locations.isEmpty) return const LatLng(29.9977, 31.4381); // fallback GUC-area coords
    final avgLat = locations.map((l) => l.latitude).reduce((a, b) => a + b) / locations.length;
    final avgLng = locations.map((l) => l.longitude).reduce((a, b) => a + b) / locations.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 17,
            minZoom: 15,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.guclyft.app',
            ),
            MarkerLayer(
              markers: locations.map((loc) {
                final isPickup = loc.id == pickupId;
                final isDestination = loc.id == destinationId;

                Color pinColor = Colors.grey.shade600;
                if (isPickup) pinColor = AppColors.yellow;
                if (isDestination) pinColor = AppColors.red;

                return Marker(
                  point: LatLng(loc.latitude, loc.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => onPinTapped(loc),
                    child: Icon(
                      Icons.location_on,
                      color: pinColor,
                      size: isPickup || isDestination ? 36 : 28,
                      shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}