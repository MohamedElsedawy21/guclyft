import 'dart:convert';
import 'api_service.dart';

class RideService {
  static Future<Map<String, dynamic>> bookRide({
    required int pickupLocationId,
    required int destinationLocationId,
    required int passengerCount,
  }) async {
    final res = await ApiService.post("/rides/book", {
      "pickup_location_id": pickupLocationId,
      "destination_location_id": destinationLocationId,
      "passenger_count": passengerCount,
      "is_prebooked": false,
    }, auth: true);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Booking failed");
    }
  }

    static Future<Map<String, dynamic>> getActiveRide() async {
    final res = await ApiService.get("/rides/mine/active", auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to check active ride");
    }
  }

  static Future<Map<String, dynamic>> getLiveStatus(int rideId) async {
    final res = await ApiService.get("/rides/$rideId/live", auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load live status");
    }
  }

  static Future<Map<String, dynamic>> scheduleRide({
    required int pickupLocationId,
    required int destinationLocationId,
    required int passengerCount,
    required DateTime scheduledTime,
  }) async {
    final res = await ApiService.post("/rides/schedule", {
      "pickup_location_id": pickupLocationId,
      "destination_location_id": destinationLocationId,
      "passenger_count": passengerCount,
      "scheduled_time": scheduledTime.toIso8601String(),
    }, auth: true);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Scheduling failed");
    }
  }
    static Future<Map<String, dynamic>> cancelRide(int rideId) async {
    final res = await ApiService.put("/rides/$rideId/cancel", {}, auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to cancel ride");
    }
  }
  static Future<List<dynamic>> getHistory() async {
    final res = await ApiService.get("/rides/mine/history", auth: true);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load past trips");
    }
  }
}