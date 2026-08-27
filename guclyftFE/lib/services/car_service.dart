import 'dart:convert';
import 'api_service.dart';

class CarService {
  static Future<Map<String, dynamic>> getNextRide() async {
    final res = await ApiService.post("/cars/next-ride", {}, auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to get next ride");
    }
  }

  static Future<Map<String, dynamic>> markArrived() async {
    final res = await ApiService.put("/cars/arrived", {}, auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to mark arrived");
    }
  }

  static Future<Map<String, dynamic>> completeRide() async {
    final res = await ApiService.put("/cars/complete", {}, auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to complete ride");
    }
  }

  static Future<String> statusCheck() async {
    final res = await ApiService.get("/cars/status-check", auth: true);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['status'];
    } else {
      throw Exception("Failed to check status");
    }
  }

  static Future<Map<String, dynamic>> getCurrent() async {
    final res = await ApiService.get("/cars/current", auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load current status");
    }
  }

  static Future<void> updateLocation(double lat, double lng) async {
    final res = await ApiService.putQuery("/cars/location", {"lat": lat.toString(), "lng": lng.toString()}, auth: true);
    if (res.statusCode != 200) {
      throw Exception("Failed to update location");
    }
  }
      static Future<Map<String, dynamic>> verifyCode(int rideId, String code) async {
    final res = await ApiService.postQuery(
      "/cars/verify-code",
      {"ride_id": rideId.toString(), "code": code},
      auth: true,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Verification failed");
    }
  }
}