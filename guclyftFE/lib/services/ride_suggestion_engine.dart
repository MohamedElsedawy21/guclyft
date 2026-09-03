/// A suggested trip derived from the user's past ride history.
class TripSuggestion {
  final String pickupName;
  final String destinationName;
  final double score;
  final int matchCount;

  TripSuggestion({
    required this.pickupName,
    required this.destinationName,
    required this.score,
    required this.matchCount,
  });
}

class RideSuggestionEngine {
  /// How close (in minutes of day) a past trip's time has to be to "now"
  /// to count as a time-of-day match.
  static const int _timeWindowMinutes = 90;

  /// Builds up to [maxSuggestions] destination suggestions from the user's
  /// past completed trips (as returned by GET /rides/mine/history),
  /// ranked by how well they match the current weekday + time of day.
  ///
  /// Falls back to the user's most frequent routes overall if nothing
  /// lines up with the current weekday/time.
  static List<TripSuggestion> suggest(
    List<Map<String, dynamic>> history, {
    DateTime? now,
    int maxSuggestions = 3,
  }) {
    final referenceTime = now ?? DateTime.now();

    // Only completed trips are a real signal of "somewhere I wanted to go".
    final completed = history.where((t) => t['status'] == 'completed').toList();
    if (completed.isEmpty) return [];

    // Group by (pickup, destination) pair.
    final Map<String, List<DateTime>> tripTimes = {};
    final Map<String, String> pickupByKey = {};
    final Map<String, String> destByKey = {};

    for (final trip in completed) {
      final createdAtStr = trip['created_at'] as String?;
      final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr)?.toLocal() : null;
      if (createdAt == null) continue;

      final pickup = trip['pickup_name'] as String? ?? '';
      final dest = trip['destination_name'] as String? ?? '';
      if (pickup.isEmpty || dest.isEmpty) continue;

      final key = "$pickup|$dest";
      tripTimes.putIfAbsent(key, () => []).add(createdAt);
      pickupByKey[key] = pickup;
      destByKey[key] = dest;
    }

    final suggestions = <TripSuggestion>[];

    for (final key in tripTimes.keys) {
      final times = tripTimes[key]!;
      int weekdayAndTimeMatches = 0;
      int weekdayOnlyMatches = 0;

      for (final t in times) {
        final sameWeekday = t.weekday == referenceTime.weekday;
        final minutesApart = _timeOfDayDiffMinutes(t, referenceTime);

        if (sameWeekday && minutesApart <= _timeWindowMinutes) {
          weekdayAndTimeMatches++;
        } else if (sameWeekday) {
          weekdayOnlyMatches++;
        }
      }

      // Score: strong weekday+time matches count most, same-weekday-only
      // matches count a little, and overall frequency is a small tiebreaker
      // so a very common route still ranks decently as a fallback.
      final score = (weekdayAndTimeMatches * 10) +
          (weekdayOnlyMatches * 2) +
          (times.length * 0.1);

      suggestions.add(TripSuggestion(
        pickupName: pickupByKey[key]!,
        destinationName: destByKey[key]!,
        score: score,
        matchCount: times.length,
      ));
    }

    suggestions.sort((a, b) => b.score.compareTo(a.score));

    // If nothing at all lined up with today's weekday/time, this still
    // returns the most frequent routes overall (score falls back to the
    // small frequency term), which is the desired fallback behavior.
    return suggestions.take(maxSuggestions).toList();
  }

  /// Minutes of difference between two DateTimes' time-of-day, wrapping
  /// correctly around midnight (e.g. 11:50pm vs 12:10am is 20 min apart).
  static int _timeOfDayDiffMinutes(DateTime a, DateTime b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    final diff = (aMinutes - bMinutes).abs();
    return diff > 720 ? 1440 - diff : diff;
  }
}