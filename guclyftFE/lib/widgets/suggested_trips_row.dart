import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ride_suggestion_engine.dart';

class SuggestedTripsRow extends StatelessWidget {
  final List<TripSuggestion> suggestions;
  final void Function(TripSuggestion) onTap;

  const SuggestedTripsRow({super.key, required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.yellow),
            const SizedBox(width: 6),
            const Text(
              "Suggested for you",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _SuggestionCard(
              suggestion: suggestions[i],
              onTap: () => onTap(suggestions[i]),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final TripSuggestion suggestion;
  final VoidCallback onTap;

  const _SuggestionCard({required this.suggestion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navy.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    suggestion.pickupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.grey),
                  ),
                  Text(
                    suggestion.destinationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.yellow,
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.black),
            ),
          ],
        ),
      ),
    );
  }
}