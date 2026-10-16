import 'package:flutter/material.dart';
import '../models/category_stats.dart';
import '../utils/statistics_calculator.dart';

/// Top header widget displaying the Overview title, time range selector, and date navigation arrows.
class StatisticsHeader extends StatelessWidget {
  final TimeRange selectedRange;
  final DateTime currentAnchorDate;
  final List<DateTime> availablePeriods;
  final int currentIndex;
  final ValueChanged<TimeRange> onRangeSelected;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  const StatisticsHeader({
    super.key,
    required this.selectedRange,
    required this.currentAnchorDate,
    required this.availablePeriods,
    required this.currentIndex,
    required this.onRangeSelected,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  PopupMenuItem<TimeRange> _buildTimeRangePopupItem(
    TimeRange range,
    String label,
    TimeRange currentRange,
  ) {
    final isSelected = range == currentRange;
    return PopupMenuItem<TimeRange>(
      value: range,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF1A73E8) : Colors.black87,
              fontSize: 13.5,
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: Color(0xFF1A73E8),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Row 1: Title and Time Range Dropdown Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              PopupMenuButton<TimeRange>(
                onSelected: onRangeSelected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                offset: const Offset(0, 36),
                itemBuilder: (context) => [
                  _buildTimeRangePopupItem(TimeRange.byDay, 'By Day', selectedRange),
                  _buildTimeRangePopupItem(TimeRange.byWeek, 'By Week', selectedRange),
                  _buildTimeRangePopupItem(TimeRange.byMonth, 'By Month', selectedRange),
                  _buildTimeRangePopupItem(TimeRange.byYear, 'By Year', selectedRange),
                  _buildTimeRangePopupItem(TimeRange.all, 'All Time', selectedRange),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        StatisticsCalculator.getTimeRangeLabel(selectedRange),
                        style: const TextStyle(
                          color: Color(0xFF1A73E8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF1A73E8),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Row 2: Date Navigator with Previous / Next Arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: onPreviousPressed == null ? Colors.black26 : Colors.black87,
                ),
                onPressed: onPreviousPressed,
              ),
              Text(
                StatisticsCalculator.getDateRangeTitle(currentAnchorDate, selectedRange),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: onNextPressed == null ? Colors.black26 : Colors.black87,
                ),
                onPressed: onNextPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
