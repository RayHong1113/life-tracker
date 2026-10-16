import 'package:flutter/material.dart';
import '../../../models/activity_category.dart';
import '../utils/category_detail_helper.dart';

/// Top summary card in category detail view presenting category icon, total time, and daily average.
class CategoryDetailSummaryCard extends StatelessWidget {
  final ActivityCategory category;
  final Duration totalDuration;
  final int dailyAvgMinutes;
  final int excludedDaysCount;

  const CategoryDetailSummaryCard({
    super.key,
    required this.category,
    required this.totalDuration,
    required this.dailyAvgMinutes,
    this.excludedDaysCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: category.color,
            child: Icon(category.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    CategoryDetailHelper.formatDuration(totalDuration),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: category.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Total Time Spent',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Container(
                height: 32,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: Colors.grey.shade300,
              ),
              Column(
                children: [
                  Text(
                    '${CategoryDetailHelper.formatDuration(Duration(minutes: dailyAvgMinutes))}/d',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Daily Average',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (excludedDaysCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '($excludedDaysCount untracked excluded)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
