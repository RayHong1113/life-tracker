import 'package:flutter/material.dart';
import '../models/category_stats.dart';
import '../utils/statistics_calculator.dart';

/// Ranked list of categories with session count, total duration, percentage, and visibility toggle.
class StatisticsCategoryList extends StatelessWidget {
  final List<CategoryStats> allStatsList;
  final Set<String> hiddenCategoryNames;
  final int denominator;
  final ValueChanged<String> onToggleVisibility;
  final ValueChanged<CategoryStats> onCategoryTapped;

  const StatisticsCategoryList({
    super.key,
    required this.allStatsList,
    required this.hiddenCategoryNames,
    required this.denominator,
    required this.onToggleVisibility,
    required this.onCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allStatsList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final stat = allStatsList[index];
        final isHidden = hiddenCategoryNames.contains(stat.category.name);
        final percentage =
            isHidden ? 0.0 : (stat.totalDuration.inMinutes / denominator) * 100;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isHidden ? 0.45 : 1.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            onTap: () => onCategoryTapped(stat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isHidden ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isHidden ? Colors.grey.shade300 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        isHidden ? Colors.grey.shade400 : stat.category.color,
                    child: Icon(stat.category.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.category.name,
                          style: TextStyle(
                            color: isHidden ? Colors.black45 : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: isHidden ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isHidden
                              ? 'Hidden from stats'
                              : '${stat.count} session${stat.count > 1 ? 's' : ''} • ${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isHidden ? Colors.black38 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    StatisticsCalculator.formatDuration(stat.totalDuration),
                    style: TextStyle(
                      color: isHidden ? Colors.black45 : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: isHidden
                          ? Colors.grey.shade500
                          : const Color(0xFF1A73E8),
                    ),
                    onPressed: () => onToggleVisibility(stat.category.name),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
