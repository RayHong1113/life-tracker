import 'package:flutter/material.dart';
import '../../../models/activity_log.dart';
import '../../../models/activity_category.dart';
import '../models/positioned_activity.dart';
import '../utils/timeline_layout_helper.dart';

class ActivityCardCell extends StatelessWidget {
  final PositionedActivity pos;
  final DateTime pageDate;
  final double gridContentWidth;
  final List<ActivityCategory> categories;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ActivityCardCell({
    super.key,
    required this.pos,
    required this.pageDate,
    required this.gridContentWidth,
    required this.categories,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activity = pos.activity;
    final startTime = activity.startTime;
    final endTime =
        activity.endTime ?? startTime.add(const Duration(hours: 1));

    final dayStart =
        DateTime(pageDate.year, pageDate.month, pageDate.day, 0, 0);
    final dayEnd =
        DateTime(pageDate.year, pageDate.month, pageDate.day, 23, 59, 59);

    final effectiveStart = startTime.isBefore(dayStart) ? dayStart : startTime;
    final effectiveEnd = endTime.isAfter(dayEnd) ? dayEnd : endTime;

    final startMinutes = effectiveStart.hour * 60 + effectiveStart.minute;
    final durationMinutes = effectiveEnd.difference(effectiveStart).inMinutes;

    final double pixelsPerMinute = TimelineLayoutHelper.hourHeight / 60.0;

    final double topOffset = (startMinutes * pixelsPerMinute) + 2.0;
    final double rawCardHeight = (durationMinutes * pixelsPerMinute) - 3.0;
    final double cardHeight = rawCardHeight.clamp(6.0, 1800.0);

    final double columnWidth = gridContentWidth / pos.totalColumns;
    final double leftOffset = TimelineLayoutHelper.timeLabelWidth +
        (pos.column * columnWidth) +
        TimelineLayoutHelper.cellHorizontalMargin;
    final double cardWidth = (columnWidth -
            (TimelineLayoutHelper.cellHorizontalMargin * 2.0))
        .clamp(20.0, gridContentWidth);

    final bool useVerticalLayout = cardWidth < 220.0 || pos.totalColumns >= 2;

    return Positioned(
      top: topOffset,
      left: leftOffset,
      width: cardWidth,
      height: cardHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardHeight < 12.0 ? 2.0 : 5.0),
        child: Container(
          decoration: BoxDecoration(
            color: activity.color,
            borderRadius: BorderRadius.circular(cardHeight < 12.0 ? 2.0 : 5.0),
            boxShadow: cardHeight < 12.0
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.only(
                  left: 6.0, right: 1.5, top: 4.0, bottom: 2.0),
              child: cardHeight < 14.0
                  ? const SizedBox.shrink()
                  : (cardWidth < 50.0
                      ? _buildCompactMicroLayout(
                          activity, startTime, cardHeight)
                      : (cardHeight < 36.0
                          ? _buildSingleLineLayout(
                              activity, startTime, endTime, cardWidth)
                          : (useVerticalLayout
                              ? _buildVerticalLayout(activity, startTime,
                                  endTime, cardHeight, cardWidth)
                              : _buildHorizontalLayout(activity, startTime,
                                  endTime, cardHeight)))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMicroLayout(
    ActivityLog activity,
    DateTime startTime,
    double cardHeight,
  ) {
    final category =
        TimelineLayoutHelper.getCategoryForActivity(activity, categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              category.icon,
              color: Colors.white,
              size: 9,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        if (cardHeight > 22.0)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              TimelineLayoutHelper.formatTime(startTime),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSingleLineLayout(
    ActivityLog activity,
    DateTime startTime,
    DateTime endTime,
    double cardWidth,
  ) {
    final category =
        TimelineLayoutHelper.getCategoryForActivity(activity, categories);
    final showFullTime = cardWidth >= 110.0;
    final showShortTime = cardWidth >= 65.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 8,
          backgroundColor: Colors.white24,
          child: Icon(
            category.icon,
            color: Colors.white,
            size: 9,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              activity.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        if (showShortTime) ...[
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                showFullTime
                    ? '${TimelineLayoutHelper.formatTime(startTime)} - ${TimelineLayoutHelper.formatTime(endTime)}'
                    : TimelineLayoutHelper.formatTime(startTime),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 9.0,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 2),
        GestureDetector(
          onTap: onDelete,
          child: const Icon(
            Icons.close,
            size: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(
    ActivityLog activity,
    DateTime startTime,
    DateTime endTime,
    double cardHeight,
  ) {
    final category =
        TimelineLayoutHelper.getCategoryForActivity(activity, categories);

    final labels = activity.labelNames.isNotEmpty
        ? activity.labelNames
        : (activity.labelName != null && activity.labelName!.isNotEmpty
            ? [activity.labelName!]
            : <String>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white24,
              child: Icon(
                category.icon,
                color: Colors.white,
                size: 9,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  activity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${TimelineLayoutHelper.formatTime(startTime)} - ${TimelineLayoutHelper.formatTime(endTime)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 1.5),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                size: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        if (cardHeight > 34.0 && activity.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 20.0),
            child: Text(
              activity.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        if (cardHeight > 50.0 && labels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3.0, left: 20.0),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: labels.map((lbl) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lbl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildVerticalLayout(
    ActivityLog activity,
    DateTime startTime,
    DateTime endTime,
    double cardHeight,
    double cardWidth,
  ) {
    final category =
        TimelineLayoutHelper.getCategoryForActivity(activity, categories);

    final labels = activity.labelNames.isNotEmpty
        ? activity.labelNames
        : (activity.labelName != null && activity.labelName!.isNotEmpty
            ? [activity.labelName!]
            : <String>[]);

    final showTime = cardHeight > 24.0;
    final showFullTime = cardWidth >= 95.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        activity.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                size: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        if (showTime) ...[
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              showFullTime
                  ? '${TimelineLayoutHelper.formatTime(startTime)} - ${TimelineLayoutHelper.formatTime(endTime)}'
                  : TimelineLayoutHelper.formatTime(startTime),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (cardHeight > 42.0 && activity.description.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            activity.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
        if (cardHeight > 58.0 && labels.isNotEmpty) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 3,
            runSpacing: 2,
            children: labels.take(2).map((lbl) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lbl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
