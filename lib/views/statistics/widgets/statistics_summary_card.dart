import 'package:flutter/material.dart';
import '../utils/statistics_calculator.dart';

/// Card widget displaying the total logged time and total activity count for the active period.
class StatisticsSummaryCard extends StatelessWidget {
  final int totalMinutesActive;
  final int totalSessionsActive;

  const StatisticsSummaryCard({
    super.key,
    required this.totalMinutesActive,
    required this.totalSessionsActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  StatisticsCalculator.formatDuration(
                    Duration(minutes: totalMinutesActive),
                  ),
                  style: const TextStyle(
                    color: Color(0xFF1A73E8),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Total Time Logged',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$totalSessionsActive',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Activities',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
