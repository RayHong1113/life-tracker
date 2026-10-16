import 'package:flutter/material.dart';
import '../../../models/activity_category.dart';
import '../../../models/activity_log.dart';
import '../utils/category_detail_helper.dart';
import '../../calendar/add_activity_screen.dart';

/// Grouped historical activity logs list with date headers and tap-to-edit support.
class CategoryDetailHistoryList extends StatelessWidget {
  final List<ActivityLog> categoryLogs;
  final Map<String, List<ActivityLog>> groupedLogs;
  final ActivityCategory category;

  const CategoryDetailHistoryList({
    super.key,
    required this.categoryLogs,
    required this.groupedLogs,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Activity Logs (${categoryLogs.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        if (categoryLogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_note, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text(
                  'No activities recorded for this period.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groupedLogs.keys.length,
            itemBuilder: (context, groupIdx) {
              final dateHeader = groupedLogs.keys.elementAt(groupIdx);
              final logs = groupedLogs[dateHeader]!;

              int dayMins = 0;
              for (var l in logs) {
                dayMins += l.duration.inMinutes;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6, right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateHeader,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          CategoryDetailHelper.formatDuration(Duration(minutes: dayMins)),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: List.generate(logs.length, (idx) {
                        final log = logs[idx];
                        final actEnd = log.endTime ?? log.startTime.add(const Duration(hours: 1));

                        BorderRadius itemRadius;
                        if (logs.length == 1) {
                          itemRadius = BorderRadius.circular(12);
                        } else if (idx == 0) {
                          itemRadius = const BorderRadius.vertical(top: Radius.circular(12));
                        } else if (idx == logs.length - 1) {
                          itemRadius = const BorderRadius.vertical(bottom: Radius.circular(12));
                        } else {
                          itemRadius = BorderRadius.zero;
                        }

                        return Column(
                          children: [
                            InkWell(
                              splashColor: category.color.withValues(alpha: 0.2),
                              hoverColor: category.color.withValues(alpha: 0.1),
                              borderRadius: itemRadius,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AddActivityScreen(
                                    selectedDate: log.startTime,
                                    existingActivity: log,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: category.color,
                                      child: Icon(category.icon, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (log.description.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 3.0, bottom: 4.0),
                                              child: Text(
                                                log.description,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ),
                                          if (log.labelNames.isNotEmpty ||
                                              (log.labelName != null &&
                                                  log.labelName!.isNotEmpty))
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: (log.labelNames.isNotEmpty
                                                        ? log.labelNames
                                                        : [log.labelName!])
                                                    .map((lbl) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF1A73E8)
                                                          .withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: const Color(0xFF1A73E8)
                                                            .withValues(alpha: 0.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      lbl,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF1A73E8),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CategoryDetailHelper.formatDuration(log.duration),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: category.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${CategoryDetailHelper.formatTimeOfDay(log.startTime)} - ${CategoryDetailHelper.formatTimeOfDay(actEnd)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (idx < logs.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}
