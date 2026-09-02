import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import 'category_detail_screen.dart';
import '../../models/activity_category.dart';

// 支持 Day, Week, Month, Year, All
enum TimeRange { byDay, byWeek, byMonth, byYear, all }

// 饼图/图表计算模式：已记录时间占比 vs 客观时间占比
enum ChartMode { loggedTime, objectiveTime }

class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  ChartMode _chartMode = ChartMode.loggedTime; // 默认：Logged Time

  // 💡 记录被隐藏的分类名称集合
  final Set<String> _hiddenCategoryNames = {};

  PageController? _pageController;
  int _currentIndex = 0;
  TimeRange? _lastSelectedRange;
  DateTime? _lastCalendarDate;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  DateTime _getPeriodAnchor(DateTime date, TimeRange selectedRange) {
    final clean = DateTime(date.year, date.month, date.day);
    switch (selectedRange) {
      case TimeRange.byDay:
        return clean;
      case TimeRange.byWeek:
        return clean.subtract(Duration(days: clean.weekday - 1));
      case TimeRange.byMonth:
        return DateTime(clean.year, clean.month, 1);
      case TimeRange.byYear:
        return DateTime(clean.year, 1, 1);
      case TimeRange.all:
        return DateTime(2026, 1, 1);
    }
  }

  // 💡 获取包含真实打卡记录、当前时间、Calendar 当前选中日期以及已访问日期的有效时间段
  List<DateTime> _getAvailablePeriods(
      List<ActivityLog> activities, TimeRange selectedRange, DateTime targetDate, DateTime? lastDate) {
    final targetAnchor = _getPeriodAnchor(targetDate, selectedRange);
    final nowAnchor = _getPeriodAnchor(DateTime.now(), selectedRange);

    if (selectedRange == TimeRange.all) {
      return [nowAnchor];
    }

    final Set<DateTime> periodSet = {nowAnchor, targetAnchor};
    if (lastDate != null) {
      periodSet.add(_getPeriodAnchor(lastDate, selectedRange));
    }
    for (var act in activities) {
      periodSet.add(_getPeriodAnchor(act.startTime, selectedRange));
    }

    final list = periodSet.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  // 生成顶部日期标题
  String _getDateRangeTitle(DateTime anchorDate, TimeRange selectedRange) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    if (selectedRange == TimeRange.byDay) {
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekDays[anchorDate.weekday - 1]}, ${months[anchorDate.month - 1]} ${anchorDate.day}, ${anchorDate.year}';
    } else if (selectedRange == TimeRange.byWeek) {
      final weekStart =
          anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      if (weekStart.month == weekEnd.month) {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
      } else {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}, ${weekStart.year}';
      }
    } else if (selectedRange == TimeRange.byMonth) {
      final fullMonths = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${fullMonths[anchorDate.month - 1]} ${anchorDate.year}';
    } else if (selectedRange == TimeRange.byYear) {
      return '${anchorDate.year}';
    } else {
      return 'All Time History';
    }
  }

  // 计算固定客观总时长 (Objective Time)
  int _calculateObjectiveMinutes(
      DateTime anchorDate, TimeRange selectedRange, List<ActivityLog> activities) {
    if (selectedRange == TimeRange.byDay) {
      return 24 * 60;
    } else if (selectedRange == TimeRange.byWeek) {
      return 7 * 24 * 60;
    } else if (selectedRange == TimeRange.byMonth) {
      final daysInMonth = DateTime(anchorDate.year, anchorDate.month + 1, 0).day;
      return daysInMonth * 24 * 60;
    } else if (selectedRange == TimeRange.byYear) {
      final isLeapYear = (anchorDate.year % 4 == 0 && anchorDate.year % 100 != 0) ||
          (anchorDate.year % 400 == 0);
      return (isLeapYear ? 366 : 365) * 24 * 60;
    } else {
      if (activities.isEmpty) return 24 * 60;
      final earliest =
          activities.map((a) => a.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      final days = DateTime.now().difference(earliest).inDays + 1;
      return days * 24 * 60;
    }
  }

  // 统计逻辑
  Map<String, _CategoryStats> _calculateStatsForPage(
      List<ActivityLog> activities,
      List<ActivityCategory> categories,
      DateTime anchorDate,
      TimeRange selectedRange) {
    final Map<String, _CategoryStats> statsMap = {};

    DateTime? windowStart;
    DateTime? windowEnd;

    if (selectedRange == TimeRange.byDay) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, anchorDate.day, 0, 0, 0);
      windowEnd = windowStart.add(const Duration(days: 1));
    } else if (selectedRange == TimeRange.byWeek) {
      final weekStart =
          anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
      windowStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
      windowEnd = windowStart.add(const Duration(days: 7));
    } else if (selectedRange == TimeRange.byMonth) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, 1);
      windowEnd = DateTime(anchorDate.year, anchorDate.month + 1, 1);
    } else if (selectedRange == TimeRange.byYear) {
      windowStart = DateTime(anchorDate.year, 1, 1);
      windowEnd = DateTime(anchorDate.year + 1, 1, 1);
    } else {
      windowStart = null;
      windowEnd = null;
    }

    for (var activity in activities) {
      final actStart = activity.startTime;
      final actEnd = activity.endTime ?? actStart.add(const Duration(hours: 1));

      if (windowStart != null && windowEnd != null) {
        if (actEnd.isBefore(windowStart) ||
            actStart.isAfter(windowEnd) ||
            actEnd.isAtSameMomentAs(windowStart) ||
            actStart.isAtSameMomentAs(windowEnd)) {
          continue;
        }
      }

      final effectiveStart = (windowStart != null && actStart.isBefore(windowStart))
          ? windowStart
          : actStart;
      final effectiveEnd = (windowEnd != null && actEnd.isAfter(windowEnd))
          ? windowEnd
          : actEnd;

      final overlapDuration = effectiveEnd.difference(effectiveStart);
      if (overlapDuration.inMinutes <= 0) continue;

      final category = categories.firstWhere(
        (cat) => cat.name.trim().toLowerCase() == activity.title.trim().toLowerCase(),
        orElse: () => ActivityCategory(
          id: activity.title,
          name: activity.title,
          icon: Icons.task_alt,
          color: activity.color,
        ),
      );

      if (statsMap.containsKey(category.name)) {
        statsMap[category.name]!.totalDuration += overlapDuration;
        statsMap[category.name]!.count += 1;
      } else {
        statsMap[category.name] = _CategoryStats(
          category: category,
          totalDuration: overlapDuration,
          count: 1,
        );
      }
    }

    return statsMap;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final selectedRange = settingsProvider.timeRange;
    final calendarDate = provider.selectedDate;
    final activities = provider.activities;
    final categories = provider.categories;

    // 💡 1. 提取包含真实打卡记录、当前时间、Calendar 当前选中日期以及已访问日期的 Period 列表
    final availablePeriods = _getAvailablePeriods(activities, selectedRange, calendarDate, _lastCalendarDate);

    final targetAnchor = _getPeriodAnchor(calendarDate, selectedRange);
    int matchedIdx = availablePeriods.indexWhere((p) => p == targetAnchor);
    if (matchedIdx == -1) {
      final nowAnchor = _getPeriodAnchor(DateTime.now(), selectedRange);
      matchedIdx = availablePeriods.indexWhere((p) => p == nowAnchor);
      if (matchedIdx == -1) {
        matchedIdx = availablePeriods.length - 1;
      }
    }

    final activeAnchor = _currentIndex < availablePeriods.length
        ? availablePeriods[_currentIndex]
        : null;

    if (_pageController == null || _lastSelectedRange != selectedRange) {
      _lastSelectedRange = selectedRange;
      _lastCalendarDate = calendarDate;
      _currentIndex = matchedIdx;
      _pageController?.dispose();
      _pageController = PageController(initialPage: _currentIndex);
    } else if (_lastCalendarDate != calendarDate ||
        activeAnchor != targetAnchor ||
        _currentIndex >= availablePeriods.length) {
      _lastCalendarDate = calendarDate;
      _currentIndex = matchedIdx;
      if (_pageController != null && _pageController!.hasClients) {
        final currentPos = _pageController!.page?.round();
        if (currentPos != matchedIdx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController != null && _pageController!.hasClients) {
              _pageController!.jumpToPage(matchedIdx);
            }
          });
        }
      }
    }

    final currentAnchorDate = availablePeriods[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // 1. Overview 标题 + 右侧时间维度切换下拉按钮
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
                        onSelected: (TimeRange range) {
                          settingsProvider.setTimeRange(range);
                        },
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
                                _getTimeRangeLabel(selectedRange),
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

                // 2. 日期翻页与标题（仅翻页到有打卡数据的时间段）
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: (selectedRange == TimeRange.all || _currentIndex <= 0)
                            ? Colors.black26
                            : Colors.black87,
                      ),
                      onPressed: (selectedRange == TimeRange.all || _currentIndex <= 0)
                          ? null
                          : () {
                              if (_pageController != null && _pageController!.hasClients) {
                                _pageController!.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                    ),
                    Text(
                      _getDateRangeTitle(currentAnchorDate, selectedRange),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: (selectedRange == TimeRange.all || _currentIndex >= availablePeriods.length - 1)
                            ? Colors.black26
                            : Colors.black87,
                      ),
                      onPressed: (selectedRange == TimeRange.all || _currentIndex >= availablePeriods.length - 1)
                          ? null
                          : () {
                              if (_pageController != null && _pageController!.hasClients) {
                                _pageController!.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              key: ValueKey(selectedRange),
              controller: _pageController,
              itemCount: availablePeriods.length,
              physics: selectedRange == TimeRange.all
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index < availablePeriods.length) {
                  final selectedDate = availablePeriods[index];
                  _lastCalendarDate = selectedDate;
                  if (provider.selectedDate != selectedDate) {
                    provider.setSelectedDate(selectedDate);
                  }
                }
              },
              itemBuilder: (context, pageIndex) {
                final pageAnchorDate = availablePeriods[pageIndex];
                final statsMap = _calculateStatsForPage(
                    activities, categories, pageAnchorDate, selectedRange);
                
                // 所有有记录的分类列表
                final allStatsList = statsMap.values.toList()
                  ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

                // 💡 过滤出未隐藏的分类（用于图表展示和分母计算）
                final activeStatsList = allStatsList
                    .where((s) => !_hiddenCategoryNames.contains(s.category.name))
                    .toList();

                // 💡 重新计算仅来自未隐藏分类的总时长与 sessions
                final totalMinutesActive = activeStatsList.fold<int>(
                    0, (sum, item) => sum + item.totalDuration.inMinutes);
                final totalSessionsActive = activeStatsList.fold<int>(
                    0, (sum, item) => sum + item.count);

                final objectiveMinutes =
                    _calculateObjectiveMinutes(pageAnchorDate, selectedRange, activities);
                
                // 计算占比用的分母（仅计算未隐藏分类的真实总时长）
                final denominator = _chartMode == ChartMode.objectiveTime
                    ? objectiveMinutes
                    : (totalMinutesActive > 0 ? totalMinutesActive : 1);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. 统计汇总 Card (仅展示未隐藏分类数据)
                      Container(
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
                                    _formatDuration(
                                        Duration(minutes: totalMinutesActive)),
                                    style: const TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Total Time Logged',
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                                height: 36,
                                width: 1,
                                color: Colors.grey.shade200),
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
                                    style: TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Categories 标题 + 模式切换 Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildModeToggleBtn(
                                    'Logged Time', ChartMode.loggedTime),
                                _buildModeToggleBtn(
                                    'Objective Time', ChartMode.objectiveTime),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (allStatsList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 42,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Activity Logs for This Day',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        )
                      else ...[
                        // 💡 只有未隐藏的分类才会绘制在图表上
                        if (activeStatsList.isEmpty)
                          Container(
                            height: 180,
                            alignment: Alignment.center,
                            child: const Text(
                              'All categories hidden.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          )
                        else if (_chartMode == ChartMode.loggedTime)
                          _buildRadialDonutChart(
                              activeStatsList, totalMinutesActive, denominator)
                        else
                          _buildObjectiveTimeBars(
                              activeStatsList, totalMinutesActive, objectiveMinutes),

                        const SizedBox(height: 16),

                        // 5. 分类明细列表（展示所有分类，包含眼睛开/关按钮与淡化显示）
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allStatsList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final stat = allStatsList[index];
                            final isHidden = _hiddenCategoryNames.contains(stat.category.name);
                            final percentage = isHidden
                                ? 0.0
                                : (stat.totalDuration.inMinutes / denominator) * 100;

                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: isHidden ? 0.45 : 1.0, // 💡 隐藏后变浅半透明
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryDetailScreen(
                                        category: stat.category,
                                        initialAnchorDate: pageAnchorDate,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: isHidden ? Colors.grey.shade100 : Colors.white,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: isHidden
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isHidden
                                          ? Colors.grey.shade400
                                          : stat.category.color,
                                      child: Icon(stat.category.icon,
                                          color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            stat.category.name,
                                            style: TextStyle(
                                              color: isHidden
                                                  ? Colors.black45
                                                  : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              decoration: isHidden
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isHidden
                                                ? 'Hidden from stats'
                                                : '${stat.count} session${stat.count > 1 ? 's' : ''} • ${percentage.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                                color: isHidden
                                                    ? Colors.black38
                                                    : Colors.black54,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(stat.totalDuration),
                                      style: TextStyle(
                                        color: isHidden
                                            ? Colors.black45
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // 💡 眼睛图标控制隐藏/显示
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
                                      onPressed: () {
                                        setState(() {
                                          if (isHidden) {
                                            _hiddenCategoryNames
                                                .remove(stat.category.name);
                                          } else {
                                            _hiddenCategoryNames
                                                .add(stat.category.name);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _getTimeRangeLabel(TimeRange range) {
    switch (range) {
      case TimeRange.byDay:
        return 'By Day';
      case TimeRange.byWeek:
        return 'By Week';
      case TimeRange.byMonth:
        return 'By Month';
      case TimeRange.byYear:
        return 'By Year';
      case TimeRange.all:
        return 'All Time';
    }
  }

  PopupMenuItem<TimeRange> _buildTimeRangePopupItem(
      TimeRange range, String label, TimeRange selectedRange) {
    final isSelected = range == selectedRange;
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

  // 模式切换按钮
  Widget _buildModeToggleBtn(String label, ChartMode mode) {
    final isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  // 客观时间 - 树状/柱状占比图
  Widget _buildObjectiveTimeBars(
      List<_CategoryStats> statsList, int totalMinutesActive, int objectiveMinutes) {
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
                'Logged ${_formatDuration(Duration(minutes: totalMinutesActive))} of ${_formatDuration(Duration(minutes: objectiveMinutes))}',
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

          // 堆叠总时间条
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

          // 分类客观时间百分比树状条
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

  // 已记录时间 - 饼图视图 (Donut Chart)
  Widget _buildRadialDonutChart(
      List<_CategoryStats> statsList, int totalMinutesActive, int denominator) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center =
              Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          const donutOuterRadius = 66.0;
          const lineLength = 24.0;

          final visibleStats = statsList.where((stat) {
            final percentage =
                (stat.totalDuration.inMinutes / denominator) * 100;
            return percentage >= 1.0;
          }).toList();

          double currentAngle = -90.0;
          List<double> rawAngles = [];

          for (var stat in statsList) {
            final sweep = (stat.totalDuration.inMinutes /
                    (totalMinutesActive > 0 ? totalMinutesActive : 1)) *
                360.0;

            final percentage =
                (stat.totalDuration.inMinutes / denominator) * 100;

            if (percentage >= 1.0) {
              rawAngles.add(currentAngle + sweep / 2.0);
            }
            currentAngle += sweep;
          }

          List<double> adjustedAngles = List.from(rawAngles);
          const minAngleGap = 18.0;

          if (adjustedAngles.length > 1) {
            for (int pass = 0; pass < 3; pass++) {
              for (int i = 0; i < adjustedAngles.length - 1; i++) {
                double diff = adjustedAngles[i + 1] - adjustedAngles[i];
                if (diff < minAngleGap) {
                  double overlap = minAngleGap - diff;
                  adjustedAngles[i] -= overlap / 2.0;
                  adjustedAngles[i + 1] += overlap / 2.0;
                }
              }
            }
          }

          final List<Widget> overlayWidgets = [];

          for (int i = 0; i < visibleStats.length; i++) {
            final stat = visibleStats[i];
            final rawRad = rawAngles[i] * (pi / 180.0);
            final adjRad = adjustedAngles[i] * (pi / 180.0);

            final percentage =
                (stat.totalDuration.inMinutes / denominator) * 100;

            final p1 = Offset(
              center.dx + donutOuterRadius * cos(rawRad),
              center.dy + donutOuterRadius * sin(rawRad),
            );

            final p2 = Offset(
              center.dx + (donutOuterRadius + lineLength) * cos(adjRad),
              center.dy + (donutOuterRadius + lineLength) * sin(adjRad),
            );

            overlayWidgets.add(
              CustomPaint(
                painter: _RadialLinePainter(
                  start: p1,
                  end: p2,
                  color: stat.category.color,
                ),
              ),
            );

            final bool isTopHalf = sin(adjRad) < 0;

            overlayWidgets.add(
              Positioned(
                left: p2.dx - 12,
                top: p2.dy - 12,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stat.category.color,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Icon(
                    stat.category.icon,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            );

            overlayWidgets.add(
              Positioned(
                left: p2.dx - 22,
                top: isTopHalf ? p2.dy - 24 : p2.dy + 13,
                child: SizedBox(
                  width: 44,
                  child: Text(
                    '${percentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: stat.category.color,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: 46,
                  sections: statsList.map((stat) {
                    return PieChartSectionData(
                      color: stat.category.color,
                      value: stat.totalDuration.inMinutes.toDouble(),
                      showTitle: false,
                      radius: 20,
                    );
                  }).toList(),
                ),
              ),
              ...overlayWidgets,
            ],
          );
        },
      ),
    );
  }
}

class _RadialLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  _RadialLinePainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CategoryStats {
  final ActivityCategory category;
  Duration totalDuration;
  int count;

  _CategoryStats({
    required this.category,
    required this.totalDuration,
    required this.count,
  });
}