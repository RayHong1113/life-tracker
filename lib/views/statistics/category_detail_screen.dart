import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_category.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import 'models/category_detail_types.dart';
import 'utils/category_detail_helper.dart';
import 'widgets/category_detail_summary_card.dart';
import 'widgets/category_detail_bar_chart.dart';
import 'widgets/category_detail_labels_section.dart';
import 'widgets/category_detail_history_list.dart';

// Re-export model for backwards compatibility with existing imports
export 'models/category_detail_types.dart';

/// Screen presenting in-depth analytics, distribution trends, sub-labels, and logs for a specific category.
class CategoryDetailScreen extends StatefulWidget {
  final ActivityCategory category;
  final DateTime initialAnchorDate;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    required this.initialAnchorDate,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  CategoryDetailGranularity _granularity = CategoryDetailGranularity.week;
  late DateTime _anchorDate;
  PageController? _pageController;
  int _currentIndex = 0;
  DateTimeRange? _customDateRange;
  bool _initializedGranularity = false;

  @override
  void initState() {
    super.initState();
    _anchorDate = widget.initialAnchorDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedGranularity) {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      _granularity = settingsProvider.categoryDetailGranularity;
      _initializedGranularity = true;
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// Displays the custom date range picker dialog.
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initial = _customDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 30),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _granularity = CategoryDetailGranularity.custom;
        _pageController?.dispose();
        _pageController = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);

    // Retrieve active period list containing recorded logs
    final availablePeriods = CategoryDetailHelper.getAvailablePeriods(
      provider.activities,
      _granularity,
      widget.category.name,
      _anchorDate,
    );

    // Identify current active period index
    final currentAnchor = CategoryDetailHelper.getPeriodAnchor(_anchorDate, _granularity);
    int matchedIdx = availablePeriods.indexWhere((p) => p == currentAnchor);
    if (matchedIdx == -1) {
      matchedIdx = availablePeriods.length - 1;
    }

    if (_pageController == null || _currentIndex >= availablePeriods.length) {
      _currentIndex = matchedIdx;
      _pageController = PageController(initialPage: _currentIndex);
    }

    final activePeriodDate = availablePeriods[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          // Granularity Dropdown (By weeks / By months / By years / All time / Custom range)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: PopupMenuButton<CategoryDetailGranularity>(
                onSelected: (val) async {
                  final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                  if (val == CategoryDetailGranularity.custom) {
                    await _selectCustomDateRange(context);
                  } else {
                    setState(() {
                      _granularity = val;
                      _pageController?.dispose();
                      _pageController = null;
                    });
                  }
                  await settingsProvider.setCategoryDetailGranularity(val);
                },
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CategoryDetailHelper.getGranularityDropdownLabel(_granularity),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 18),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: CategoryDetailGranularity.week,
                    child: Text('By weeks'),
                  ),
                  const PopupMenuItem(
                    value: CategoryDetailGranularity.month,
                    child: Text('By months'),
                  ),
                  const PopupMenuItem(
                    value: CategoryDetailGranularity.year,
                    child: Text('By years'),
                  ),
                  const PopupMenuItem(
                    value: CategoryDetailGranularity.all,
                    child: Text('All time'),
                  ),
                  const PopupMenuItem(
                    value: CategoryDetailGranularity.custom,
                    child: Text('Custom range'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Standard Mode Period Navigation Header
          if (_granularity != CategoryDetailGranularity.all &&
              _granularity != CategoryDetailGranularity.custom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  // Previous Period
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _currentIndex > 0
                          ? InkWell(
                              onTap: () {
                                _pageController?.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.chevron_left, size: 16, color: Colors.black38),
                                    Flexible(
                                      child: Text(
                                        CategoryDetailHelper.formatPeriodLabel(
                                          availablePeriods[_currentIndex - 1],
                                          _granularity,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // Current Active Period (Center bold)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      CategoryDetailHelper.formatPeriodLabel(activePeriodDate, _granularity),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                    ),
                  ),

                  // Next Period
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _currentIndex < availablePeriods.length - 1
                          ? InkWell(
                              onTap: () {
                                _pageController?.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        CategoryDetailHelper.formatPeriodLabel(
                                          availablePeriods[_currentIndex + 1],
                                          _granularity,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 16, color: Colors.black38),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),

          // Custom Date Range Header
          if (_granularity == CategoryDetailGranularity.custom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.date_range, color: Color(0xFF1A73E8), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _customDateRange != null
                          ? '${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}'
                          : 'Custom Date Range',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar, color: Color(0xFF1A73E8), size: 20),
                    onPressed: () => _selectCustomDateRange(context),
                    tooltip: 'Change Custom Date Range',
                  ),
                ],
              ),
            ),

          // Horizontal Smooth PageView
          Expanded(
            child: PageView.builder(
              key: ValueKey(_granularity),
              controller: _pageController,
              itemCount: availablePeriods.length,
              physics: (_granularity == CategoryDetailGranularity.all ||
                      _granularity == CategoryDetailGranularity.custom)
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _anchorDate = availablePeriods[idx];
                });
              },
              itemBuilder: (context, pageIdx) {
                final periodDate = availablePeriods[pageIdx];
                return _buildPeriodDetailContent(context, provider, periodDate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDetailContent(
    BuildContext context,
    ActivityProvider provider,
    DateTime targetPeriodDate,
  ) {
    // 1. Filter activities for this category
    final rawCategoryActs = provider.activities.where((act) =>
        act.title.trim().toLowerCase() == widget.category.name.trim().toLowerCase());

    // 2. Slice cross-day logs into per-day segments
    final slicedLogs = rawCategoryActs
        .expand(CategoryDetailHelper.sliceActivityByDay)
        .toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 3. Filter logs that fall within targetPeriodDate
    final categoryLogs = slicedLogs.where((act) {
      final actStart = act.startTime;
      final actEnd = act.endTime ??
          DateTime(
            actStart.year,
            actStart.month,
            actStart.day,
            actStart.hour + 1,
            actStart.minute,
            actStart.second,
          );

      switch (_granularity) {
        case CategoryDetailGranularity.week:
          final weekStart = CategoryDetailHelper.getStartOfWeek(targetPeriodDate);
          final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
          return actStart.isBefore(weekEnd) && actEnd.isAfter(weekStart);

        case CategoryDetailGranularity.month:
          final monthStart = DateTime(targetPeriodDate.year, targetPeriodDate.month, 1);
          final monthEnd = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 1);
          return actStart.isBefore(monthEnd) && actEnd.isAfter(monthStart);

        case CategoryDetailGranularity.year:
          final yearStart = DateTime(targetPeriodDate.year, 1, 1);
          final yearEnd = DateTime(targetPeriodDate.year + 1, 1, 1);
          return actStart.isBefore(yearEnd) && actEnd.isAfter(yearStart);

        case CategoryDetailGranularity.custom:
          final rawStart = _customDateRange?.start ?? DateTime(now.year, now.month, now.day - 30);
          final rawEnd = _customDateRange?.end ?? today;
          final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
          final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day + 1);
          return actStart.isBefore(end) && actEnd.isAfter(start);

        case CategoryDetailGranularity.all:
          return true;
      }
    }).toList();

    // Sort logs descending by start time
    categoryLogs.sort((a, b) => b.startTime.compareTo(a.startTime));

    int totalCategoryMinutes = 0;
    for (var log in categoryLogs) {
      totalCategoryMinutes += log.duration.inMinutes;
    }
    final totalDuration = Duration(minutes: totalCategoryMinutes);

    // Compute earliest recorded date
    DateTime allTimeEarliest = categoryLogs.isEmpty
        ? DateTime(now.year, now.month, 1)
        : categoryLogs.map((l) => l.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    allTimeEarliest = DateTime(allTimeEarliest.year, allTimeEarliest.month, 1);

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final excludedDates = settingsProvider.excludedDates;

    int activeDays = 1;
    int excludedCountInPeriod = 0;

    switch (_granularity) {
      case CategoryDetailGranularity.week:
        final weekStart = CategoryDetailHelper.getStartOfWeek(targetPeriodDate);
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
        final isCurrentWeek = !today.isBefore(weekStart) && !today.isAfter(weekEnd);

        if (isCurrentWeek) {
          // Current in-progress week: count only days elapsed up to today
          activeDays = CategoryDetailHelper.daysBetween(weekStart, today) + 1;
          for (int i = 0; i < activeDays; i++) {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        } else {
          // Full 7-day week
          activeDays = 7;
          for (int i = 0; i < 7; i++) {
            final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        }
        break;

      case CategoryDetailGranularity.month:
        final daysInMonth = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 0).day;
        final isCurrentMonth = today.year == targetPeriodDate.year && today.month == targetPeriodDate.month;

        if (isCurrentMonth) {
          // Current in-progress month: count only days elapsed up to today
          activeDays = today.day;
          for (int i = 1; i <= activeDays; i++) {
            final day = DateTime(targetPeriodDate.year, targetPeriodDate.month, i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        } else {
          // Full month with daysInMonth days
          activeDays = daysInMonth;
          for (int i = 1; i <= daysInMonth; i++) {
            final day = DateTime(targetPeriodDate.year, targetPeriodDate.month, i);
            final key = SettingsProvider.formatDateKey(day);
            if (excludedDates.contains(key)) {
              excludedCountInPeriod++;
            }
          }
        }
        break;

      case CategoryDetailGranularity.year:
        final isLeapYear = (targetPeriodDate.year % 4 == 0 && targetPeriodDate.year % 100 != 0) ||
            (targetPeriodDate.year % 400 == 0);
        final totalDaysInYear = isLeapYear ? 366 : 365;
        final isCurrentYear = today.year == targetPeriodDate.year;

        if (isCurrentYear) {
          // Current in-progress year: count only days elapsed up to today
          final yearStart = DateTime(targetPeriodDate.year, 1, 1);
          activeDays = CategoryDetailHelper.daysBetween(yearStart, today) + 1;
          for (final key in excludedDates) {
            if (key.startsWith('${targetPeriodDate.year}-')) {
              try {
                final parts = key.split('-');
                final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                if (!d.isAfter(today)) {
                  excludedCountInPeriod++;
                }
              } catch (_) {}
            }
          }
        } else {
          // Full year
          activeDays = totalDaysInYear;
          for (final key in excludedDates) {
            if (key.startsWith('${targetPeriodDate.year}-')) {
              excludedCountInPeriod++;
            }
          }
        }
        break;

      case CategoryDetailGranularity.custom:
        final rawStart = _customDateRange?.start ?? DateTime(now.year, now.month, now.day - 30);
        final rawEnd = _customDateRange?.end ?? today;
        final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
        final end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);

        // Cap effective end date at today if ongoing
        final isOngoing = !today.isBefore(start) && !today.isAfter(end);
        final effectiveEnd = isOngoing ? today : end;
        activeDays = max(1, CategoryDetailHelper.daysBetween(start, effectiveEnd) + 1);
        for (int i = 0; i < activeDays; i++) {
          final day = DateTime(start.year, start.month, start.day + i);
          final key = SettingsProvider.formatDateKey(day);
          if (excludedDates.contains(key)) {
            excludedCountInPeriod++;
          }
        }
        break;

      case CategoryDetailGranularity.all:
        final firstDate = categoryLogs.isEmpty ? today : categoryLogs.last.startTime;
        final cleanFirst = DateTime(firstDate.year, firstDate.month, firstDate.day);
        final totalDays = max(1, CategoryDetailHelper.daysBetween(cleanFirst, today) + 1);
        activeDays = totalDays;
        for (int i = 0; i < totalDays; i++) {
          final day = DateTime(cleanFirst.year, cleanFirst.month, cleanFirst.day + i);
          final key = SettingsProvider.formatDateKey(day);
          if (excludedDates.contains(key)) {
            excludedCountInPeriod++;
          }
        }
        break;
    }

    // Subtract excluded untracked days from active period days
    final effectiveDays = max(1, activeDays - excludedCountInPeriod);
    final dailyAvgMinutes = (totalCategoryMinutes / effectiveDays).round();

    // Build bar chart series data
    final Map<int, int> chartMinutes = {};
    int barCount = 7;
    if (_granularity == CategoryDetailGranularity.week) {
      barCount = 7;
      for (int i = 1; i <= 7; i++) {
        chartMinutes[i] = 0;
      }
      for (var log in categoryLogs) {
        final weekday = log.startTime.weekday;
        if (weekday >= 1 && weekday <= 7) {
          chartMinutes[weekday] =
              (chartMinutes[weekday] ?? 0) + log.duration.inMinutes;
        }
      }
    } else if (_granularity == CategoryDetailGranularity.month) {
      barCount = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 0).day;
      for (int i = 1; i <= barCount; i++) {
        chartMinutes[i] = 0;
      }
      for (var log in categoryLogs) {
        final day = log.startTime.day;
        chartMinutes[day] = (chartMinutes[day] ?? 0) + log.duration.inMinutes;
      }
    } else if (_granularity == CategoryDetailGranularity.year) {
      barCount = 12;
      for (int i = 1; i <= 12; i++) {
        chartMinutes[i] = 0;
      }
      for (var log in categoryLogs) {
        final month = log.startTime.month;
        chartMinutes[month] = (chartMinutes[month] ?? 0) + log.duration.inMinutes;
      }
    } else if (_granularity == CategoryDetailGranularity.custom) {
      barCount = activeDays;
      for (int i = 1; i <= barCount; i++) {
        chartMinutes[i] = 0;
      }
      final rawStart = _customDateRange?.start ?? DateTime(now.year, now.month, now.day - 30);
      final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
      for (var log in categoryLogs) {
        final dayOffset = CategoryDetailHelper.daysBetween(start, log.startTime) + 1;
        if (dayOffset >= 1 && dayOffset <= barCount) {
          chartMinutes[dayOffset] =
              (chartMinutes[dayOffset] ?? 0) + log.duration.inMinutes;
        }
      }
    } else {
      final nowMonth = DateTime(now.year, now.month, 1);
      int totalAllTimeMonths = (nowMonth.year - allTimeEarliest.year) * 12 +
          (nowMonth.month - allTimeEarliest.month) + 1;
      totalAllTimeMonths = max(1, totalAllTimeMonths);

      barCount = totalAllTimeMonths;
      for (int i = 1; i <= barCount; i++) {
        chartMinutes[i] = 0;
      }
      for (var log in categoryLogs) {
        final monthOffset = (log.startTime.year - allTimeEarliest.year) * 12 +
            (log.startTime.month - allTimeEarliest.month) + 1;
        if (monthOffset >= 1 && monthOffset <= barCount) {
          chartMinutes[monthOffset] =
              (chartMinutes[monthOffset] ?? 0) + log.duration.inMinutes;
        }
      }
    }

    final maxChartMinutes = chartMinutes.values.isEmpty
        ? 60
        : max(60, chartMinutes.values.reduce(max));

    // Group logs by date string header
    final Map<String, List<ActivityLog>> groupedLogs = {};
    for (var log in categoryLogs) {
      final key = CategoryDetailHelper.formatDateHeader(log.startTime);
      groupedLogs.putIfAbsent(key, () => []).add(log);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Top Summary Card
          CategoryDetailSummaryCard(
            category: widget.category,
            totalDuration: totalDuration,
            dailyAvgMinutes: dailyAvgMinutes,
            excludedDaysCount: excludedCountInPeriod,
          ),
          const SizedBox(height: 16),

          // Distribution Bar Chart Card
          CategoryDetailBarChart(
            granularity: _granularity,
            categoryColor: widget.category.color,
            targetPeriodDate: targetPeriodDate,
            allTimeEarliest: allTimeEarliest,
            customDateRange: _customDateRange,
            chartMinutes: chartMinutes,
            barCount: barCount,
            maxChartMinutes: maxChartMinutes,
          ),
          const SizedBox(height: 16),

          // Spendee-style Labels Breakdown
          CategoryDetailLabelsSection(
            categoryLogs: categoryLogs,
          ),

          // Grouped Activity History Logs
          CategoryDetailHistoryList(
            categoryLogs: categoryLogs,
            groupedLogs: groupedLogs,
            category: widget.category,
          ),
        ],
      ),
    );
  }
}
