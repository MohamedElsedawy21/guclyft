import 'dart:convert';
import 'api_service.dart';

class RatingService {
  /// Submits a rating for a completed ride.
  /// [smoothness], [punctuality] and [cleanliness] are optional sub-ratings (1-5).
  static Future<Map<String, dynamic>> rateRide({
    required int rideId,
    required int stars,
    int? smoothness,
    int? punctuality,
    int? cleanliness,
    String? comment,
  }) async {
    final body = {
      "stars": stars,
      if (smoothness != null) "smoothness": smoothness,
      if (punctuality != null) "punctuality": punctuality,
      if (cleanliness != null) "cleanliness": cleanliness,
      if (comment != null && comment.trim().isNotEmpty) "comment": comment.trim(),
    };

    final res = await ApiService.post("/rides/$rideId/rate", body, auth: true);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      final error = jsonDecode(res.body);
      throw Exception(error['detail'] ?? "Failed to submit rating");
    }
  }

  /// Returns the rating for a ride, or null if it hasn't been rated yet.
  static Future<Map<String, dynamic>?> getRating(int rideId) async {
    final res = await ApiService.get("/rides/$rideId/rating", auth: true);
    if (res.statusCode == 200) {
      if (res.body.isEmpty || res.body == "null") return null;
      return jsonDecode(res.body);
    } else {
      throw Exception("Failed to load rating");
    }
  }
}