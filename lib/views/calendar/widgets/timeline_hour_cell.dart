import 'package:flutter/material.dart';
import '../../../models/activity_log.dart';
import '../utils/timeline_layout_helper.dart';

class TimelineHourCell extends StatelessWidget {
  final int hour;
  final List<ActivityLog> pageActivities;
  final DateTime pageDate;
  final int? selectedHour;
  final bool isFullHourSelected;
  final VoidCallback onSelectFullHour;
  final VoidCallback onSelectRemainingSlot;

  const TimelineHourCell({
    super.key,
    required this.hour,
    required this.pageActivities,
    required this.pageDate,
    required this.selectedHour,
    required this.isFullHourSelected,
    required this.onSelectFullHour,
    required this.onSelectRemainingSlot,
  });

  @override
  Widget build(BuildContext context) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final isSelected = selectedHour == hour;

    final occupiedMinutes = TimelineLayoutHelper.getOccupiedMinutesInHour(
      pageDate,
      hour,
      pageActivities,
    );

    final startMinute = (isSelected && isFullHourSelected)
        ? 0
        : (occupiedMinutes < 60 ? occupiedMinutes : 0);

    return SizedBox(
      height: TimelineLayoutHelper.hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 💡 1. 左侧时间标尺：点击选择【整个小时段】
          SizedBox(
            width: TimelineLayoutHelper.timeLabelWidth,
            child: InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: onSelectFullHour,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$formattedHour $amPm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? const Color(0xFF1A73E8) : Colors.grey,
                  ),
                ),
              ),
            ),
          ),

          // 💡 2. 右侧空白区域：点击选择【剩余可用时间段】
          Expanded(
            child: InkWell(
              onTap: onSelectRemainingSlot,
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 1.0,
                      horizontal: TimelineLayoutHelper.cellHorizontalMargin,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.0),
                      border:
                          Border.all(color: Colors.grey.shade300, width: 1.0),
                    ),
                  ),
                  if (isSelected &&
                      (occupiedMinutes < 60 || isFullHourSelected)) ...[
                    Positioned(
                      top: (startMinute / 60.0) *
                              TimelineLayoutHelper.hourHeight +
                          1.0,
                      bottom: 1.0,
                      left: TimelineLayoutHelper.cellHorizontalMargin,
                      right: TimelineLayoutHelper.cellHorizontalMargin,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: const Color(0xFF1A73E8),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
