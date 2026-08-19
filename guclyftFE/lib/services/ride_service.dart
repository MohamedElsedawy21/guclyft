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
}