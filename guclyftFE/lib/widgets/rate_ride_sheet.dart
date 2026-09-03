import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/rating_service.dart';
import 'star_rating.dart';

/// Shows the "Rate your ride" bottom sheet. Returns the created rating map
/// on success, or null if the user dismissed it without rating.
Future<Map<String, dynamic>?> showRateRideSheet(BuildContext context, int rideId) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RateRideSheet(rideId: rideId),
  );
}

class RateRideSheet extends StatefulWidget {
  final int rideId;
  const RateRideSheet({super.key, required this.rideId});

  @override
  State<RateRideSheet> createState() => _RateRideSheetState();
}

class _RateRideSheetState extends State<RateRideSheet> {
  int _stars = 0;
  int _smoothness = 0;
  int _punctuality = 0;
  int _cleanliness = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = "Please select an overall rating");
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await RatingService.rateRide(
        rideId: widget.rideId,
        stars: _stars,
        smoothness: _smoothness == 0 ? null : _smoothness,
        punctuality: _punctuality == 0 ? null : _punctuality,
        cleanliness: _cleanliness == 0 ? null : _cleanliness,
        comment: _commentController.text,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                "How was your ride?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 4),
              const Text(
                "Your feedback helps us improve Guclyft",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              StarRatingInput(value: _stars, onChanged: (v) => setState(() => _stars = v)),
              const SizedBox(height: 8),
              _subRatingRow("Smoothness", _smoothness, (v) => setState(() => _smoothness = v)),
              _subRatingRow("Punctuality", _punctuality, (v) => setState(() => _punctuality = v)),
              _subRatingRow("Cleanliness", _cleanliness, (v) => setState(() => _cleanliness = v)),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Add a comment (optional)",
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: AppColors.black, strokeWidth: 2),
                      )
                    : const Text("Submit Rating"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text("Maybe later"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subRatingRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          Expanded(child: StarRatingInput(value: value, onChanged: onChanged, size: 22)),
        ],
      ),
    );
  }
}