import 'package:flutter/material.dart';
import '../../../models/activity_log.dart';
import '../utils/category_detail_helper.dart';

/// Labels breakdown card displaying duration spent per label within the selected category.
class CategoryDetailLabelsSection extends StatelessWidget {
  final List<ActivityLog> categoryLogs;

  const CategoryDetailLabelsSection({
    super.key,
    required this.categoryLogs,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, List<ActivityLog>> labelGroups = {};
    for (var log in categoryLogs) {
      final list = log.labelNames.isNotEmpty
          ? log.labelNames
          : (log.labelName != null && log.labelName!.isNotEmpty
              ? [log.labelName!]
              : <String>[]);
      for (var lbl in list) {
        labelGroups.putIfAbsent(lbl, () => []).add(log);
      }
    }

    if (labelGroups.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Labels Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...labelGroups.entries.map((entry) {
            final labelName = entry.key;
            final logs = entry.value;
            int totalMins = 0;
            for (var l in logs) {
              totalMins += l.duration.inMinutes;
            }

            const themeColor = Color(0xFF1A73E8);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      labelName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${logs.length} log${logs.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    CategoryDetailHelper.formatDuration(Duration(minutes: totalMins)),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
