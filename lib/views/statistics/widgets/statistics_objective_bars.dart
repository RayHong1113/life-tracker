import 'dart:math';
import 'package:flutter/material.dart';
import '../models/category_stats.dart';
import '../utils/statistics_calculator.dart';

/// Objective time visualizer presenting a stacked horizontal progress bar and categorized progress bars.
class StatisticsObjectiveBars extends StatelessWidget {
  final List<CategoryStats> statsList;
  final int totalMinutesActive;
  final int objectiveMinutes;

  const StatisticsObjectiveBars({
    super.key,
    required this.statsList,
    required this.totalMinutesActive,
    required this.objectiveMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final unloggedMinutes = max(0, objectiveMinutes - totalMinutesActive);
    final totalLoggedPct = (totalMinutesActive / objectiveMinutes) * 100;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Logged ${StatisticsCalculator.formatDuration(Duration(minutes: totalMinutesActive))} of ${StatisticsCalculator.formatDuration(Duration(minutes: objectiveMinutes))}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${totalLoggedPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: totalLoggedPct > 100 ? Colors.orangeAccent : const Color(0xFF1A73E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Stacked Time Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  ...statsList.map((stat) {
                    final flex = stat.totalDuration.inMinutes;
                    if (flex <= 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: flex,
                      child: Container(color: stat.category.color),
                    );
                  }),
                  if (unloggedMinutes > 0)
                    Expanded(
                      flex: unloggedMinutes,
                      child: Container(color: Colors.grey.shade200),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Categorized Linear Progress Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: statsList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final stat = statsList[index];
              final pct = (stat.totalDuration.inMinutes / objectiveMinutes) * 100;
              final barRatio =
                  (stat.totalDuration.inMinutes / objectiveMinutes).clamp(0.0, 1.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(stat.category.icon, size: 14, color: stat.category.color),
                      const SizedBox(width: 6),
                      Text(
                        stat.category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: barRatio,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: stat.category.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
