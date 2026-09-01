import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

class MapPin {
  final double lat;
  final double lng;
  final Color color;
  final IconData icon;
  final double size;

  MapPin({
    required this.lat,
    required this.lng,
    required this.color,
    this.icon = Icons.location_on,
    this.size = 36,
  });
}

class CampusMap extends StatelessWidget {
  final List<AppLocation> locations;
  final int? pickupId;
  final int? destinationId;
  final void Function(AppLocation)? onPinTapped;
  final double height;
  final List<List<double>>? path; // [[lat, lng], ...]
  final List<MapPin>? extraPins;

  const CampusMap({
    super.key,
    this.locations = const [],
    this.pickupId,
    this.destinationId,
    this.onPinTapped,
    this.height = 220,
    this.path,
    this.extraPins,
  });

  LatLng get _center {
    if (extraPins != null && extraPins!.isNotEmpty) {
      final p = extraPins!.first;
      return LatLng(p.lat, p.lng);
    }
    if (locations.isEmpty) return const LatLng(29.9977, 31.4381);
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
            if (path != null && path!.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: path!.map((p) => LatLng(p[0], p[1])).toList(),
                    strokeWidth: 4,
                    color: AppColors.yellow,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                ...locations.map((loc) {
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
                      onTap: onPinTapped != null ? () => onPinTapped!(loc) : null,
                      child: Icon(
                        Icons.location_on,
                        color: pinColor,
                        size: isPickup || isDestination ? 36 : 28,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  );
                }),
                if (extraPins != null)
                  ...extraPins!.map((p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: p.size + 6,
                        height: p.size + 6,
                        child: Icon(
                          p.icon,
                          color: p.color,
                          size: p.size,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}