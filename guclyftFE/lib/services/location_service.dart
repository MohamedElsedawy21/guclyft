import 'dart:convert';
import 'api_service.dart';
import '../data/campus_coords.dart';

class AppLocation {
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  AppLocation({required this.id, required this.name, required this.latitude, required this.longitude});

  factory AppLocation.fromJson(Map<String, dynamic> json) {
    final coords = campusCoords[json['name']];
    return AppLocation(
      id: json['id'],
      name: json['name'],
      latitude: coords != null ? coords[0] : (json['latitude'] as num).toDouble(),
      longitude: coords != null ? coords[1] : (json['longitude'] as num).toDouble(),
    );
  }
}

class LocationService {
  static Future<List<AppLocation>> getLocations() async {
    final res = await ApiService.get("/locations", auth: true);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => AppLocation.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load locations");
    }
  }
}