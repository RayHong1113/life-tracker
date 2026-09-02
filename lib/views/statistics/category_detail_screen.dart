import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/activity_category.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import '../calendar/add_activity_screen.dart';

enum CategoryDetailGranularity {
  week,
  month,
  year,
  custom,
  all,
}

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

  // 💡 弹出原生日期区间选择器 (Custom Date Range Picker)
  Future<void> _selectCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initial = _customDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
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

  DateTime _getStartOfWeek(DateTime date) {
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: dayOfWeek - 1));
  }

  DateTime _getPeriodAnchor(DateTime date, CategoryDetailGranularity gran) {
    switch (gran) {
      case CategoryDetailGranularity.week:
        return _getStartOfWeek(date);
      case CategoryDetailGranularity.month:
        return DateTime(date.year, date.month, 1);
      case CategoryDetailGranularity.year:
        return DateTime(date.year, 1, 1);
      case CategoryDetailGranularity.custom:
      case CategoryDetailGranularity.all:
        return DateTime(2026, 1, 1);
    }
  }

  // 💡 过滤提取所有【包含实际数据】的有效时间段 (Skip Empty Periods)
  List<DateTime> _getAvailablePeriods(
      List<ActivityLog> allLogs, CategoryDetailGranularity gran) {
    final categoryLogs = allLogs.where((act) =>
        act.title.trim().toLowerCase() == widget.category.name.trim().toLowerCase()).toList();

    if (categoryLogs.isEmpty || gran == CategoryDetailGranularity.all || gran == CategoryDetailGranularity.custom) {
      return [_getPeriodAnchor(_anchorDate, gran)];
    }

    final Set<DateTime> periodSet = {};
    for (var log in categoryLogs) {
      periodSet.add(_getPeriodAnchor(log.startTime, gran));
    }

    final list = periodSet.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  String _formatPeriodLabel(DateTime date, CategoryDetailGranularity gran) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    switch (gran) {
      case CategoryDetailGranularity.week:
        final start = _getStartOfWeek(date);
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${shortMonths[start.month - 1]} ${start.day} - ${end.day}';
        }
        return '${shortMonths[start.month - 1]} ${start.day} - ${shortMonths[end.month - 1]} ${end.day}';

      case CategoryDetailGranularity.month:
        return '${months[date.month - 1]} ${date.year}';

      case CategoryDetailGranularity.year:
        return '${date.year}';

      case CategoryDetailGranularity.custom:
        if (_customDateRange != null) {
          final s = _customDateRange!.start;
          final e = _customDateRange!.end;
          return '${shortMonths[s.month - 1]} ${s.day}, ${s.year} - ${shortMonths[e.month - 1]} ${e.day}, ${e.year}';
        }
        return 'Custom Range';

      case CategoryDetailGranularity.all:
        return 'All Time';
    }
  }

  String _getGranularityDropdownLabel(CategoryDetailGranularity gran) {
    switch (gran) {
      case CategoryDetailGranularity.week:
        return 'By weeks';
      case CategoryDetailGranularity.month:
        return 'By months';
      case CategoryDetailGranularity.year:
        return 'By years';
      case CategoryDetailGranularity.custom:
        return 'Custom';
      case CategoryDetailGranularity.all:
        return 'All time';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  String _formatTimeOfDay(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);

    // 1. 获取所有含有有效数据的 Period 列表
    final availablePeriods = _getAvailablePeriods(provider.activities, _granularity);

    // 2. 找到当前 period 的 index
    final currentAnchor = _getPeriodAnchor(_anchorDate, _granularity);
    int matchedIdx = availablePeriods.indexWhere((p) => p == currentAnchor);
    if (matchedIdx == -1) {
      matchedIdx = availablePeriods.length - 1; // 默认停留在最新有数据的 period
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
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // 💡 1:1 Spendee Granularity Dropdown (By weeks / By months / By years / Custom / All time)
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
                        _getGranularityDropdownLabel(_granularity),
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
          // 💡 1. 标准模式 Header（按周/按月/按年）
          if (_granularity != CategoryDetailGranularity.all && _granularity != CategoryDetailGranularity.custom)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 上一个有效时间段 (Previous Period)
                  if (_currentIndex > 0)
                    InkWell(
                      onTap: () {
                        _pageController?.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          _formatPeriodLabel(availablePeriods[_currentIndex - 1], _granularity),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),

                  // 当前选中时间段 (Current Active Period, 黑色加粗)
                  Text(
                    _formatPeriodLabel(activePeriodDate, _granularity),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  // 下一个有效时间段 (Next Period)
                  if (_currentIndex < availablePeriods.length - 1)
                    InkWell(
                      onTap: () {
                        _pageController?.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          _formatPeriodLabel(availablePeriods[_currentIndex + 1], _granularity),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 60),
                ],
              ),
            ),

          // 💡 2. Custom 自定义时间段 Header（展示日期区间 + 日历修改按钮）
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
                      _formatPeriodLabel(DateTime.now(), _granularity),
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

          // 💡 左右滑动带原生平滑动画的 PageView Body
          Expanded(
            child: PageView.builder(
              key: ValueKey(_granularity),
              controller: _pageController,
              itemCount: availablePeriods.length,
              physics: (_granularity == CategoryDetailGranularity.all || _granularity == CategoryDetailGranularity.custom)
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
      BuildContext context, ActivityProvider provider, DateTime targetPeriodDate) {
    // Filter activities matching this category name within targetPeriodDate
    final categoryLogs = provider.activities.where((act) {
      final matchesCategory =
          act.title.trim().toLowerCase() == widget.category.name.trim().toLowerCase();
      if (!matchesCategory) return false;

      final actStart = act.startTime;

      switch (_granularity) {
        case CategoryDetailGranularity.week:
          final weekStart = _getStartOfWeek(targetPeriodDate);
          final weekEnd = weekStart.add(const Duration(days: 7));
          return actStart.isAfter(weekStart.subtract(const Duration(milliseconds: 1))) &&
              actStart.isBefore(weekEnd);

        case CategoryDetailGranularity.month:
          final monthStart = DateTime(targetPeriodDate.year, targetPeriodDate.month, 1);
          final monthEnd = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 1);
          return actStart.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
              actStart.isBefore(monthEnd);

        case CategoryDetailGranularity.year:
          final yearStart = DateTime(targetPeriodDate.year, 1, 1);
          final yearEnd = DateTime(targetPeriodDate.year + 1, 1, 1);
          return actStart.isAfter(yearStart.subtract(const Duration(milliseconds: 1))) &&
              actStart.isBefore(yearEnd);

        case CategoryDetailGranularity.custom:
          final start = _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
          final end = (_customDateRange?.end ?? DateTime.now()).add(const Duration(days: 1));
          return actStart.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
              actStart.isBefore(end);

        case CategoryDetailGranularity.all:
          return true;
      }
    }).toList();

    // Sort by startTime descending
    categoryLogs.sort((a, b) => b.startTime.compareTo(a.startTime));

    // Calculate total duration
    int totalCategoryMinutes = 0;
    for (var log in categoryLogs) {
      totalCategoryMinutes += log.duration.inMinutes;
    }
    final totalDuration = Duration(minutes: totalCategoryMinutes);

    // All time earliest date calculation
    DateTime allTimeEarliest = categoryLogs.isEmpty
        ? DateTime(DateTime.now().year, DateTime.now().month, 1)
        : categoryLogs.map((l) => l.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    allTimeEarliest = DateTime(allTimeEarliest.year, allTimeEarliest.month, 1);
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    int totalAllTimeMonths = (nowMonth.year - allTimeEarliest.year) * 12 +
        (nowMonth.month - allTimeEarliest.month) + 1;
    totalAllTimeMonths = max(1, totalAllTimeMonths);

    // Days count for daily average calculation
    int activeDays = 1;
    switch (_granularity) {
      case CategoryDetailGranularity.week:
        activeDays = 7;
        break;
      case CategoryDetailGranularity.month:
        activeDays = DateTime(targetPeriodDate.year, targetPeriodDate.month + 1, 0).day;
        break;
      case CategoryDetailGranularity.year:
        activeDays = 365;
        break;
      case CategoryDetailGranularity.custom:
        if (_customDateRange != null) {
          activeDays = max(1, _customDateRange!.end.difference(_customDateRange!.start).inDays + 1);
        } else {
          activeDays = 30;
        }
        break;
      case CategoryDetailGranularity.all:
        final firstDate = categoryLogs.isEmpty ? DateTime.now() : categoryLogs.last.startTime;
        activeDays = max(1, DateTime.now().difference(firstDate).inDays);
        break;
    }
    final dailyAvgMinutes = (totalCategoryMinutes / activeDays).round();

    // Bar chart data construction
    final Map<int, int> chartMinutes = {};
    int barCount = 7;
    if (_granularity == CategoryDetailGranularity.week) {
      barCount = 7;
      for (int i = 1; i <= 7; i++) {
        chartMinutes[i] = 0;
      }
      final weekStart = _getStartOfWeek(targetPeriodDate);
      for (var log in categoryLogs) {
        final dayOffset = log.startTime.difference(weekStart).inDays + 1;
        if (dayOffset >= 1 && dayOffset <= 7) {
          chartMinutes[dayOffset] = (chartMinutes[dayOffset] ?? 0) + log.duration.inMinutes;
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
      final start = _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
      for (var log in categoryLogs) {
        final dayOffset = log.startTime.difference(start).inDays + 1;
        if (dayOffset >= 1 && dayOffset <= barCount) {
          chartMinutes[dayOffset] = (chartMinutes[dayOffset] ?? 0) + log.duration.inMinutes;
        }
      }
    } else {
      // All time dynamic monthly distribution
      barCount = totalAllTimeMonths;
      for (int i = 1; i <= barCount; i++) {
        chartMinutes[i] = 0;
      }
      for (var log in categoryLogs) {
        final monthOffset = (log.startTime.year - allTimeEarliest.year) * 12 +
            (log.startTime.month - allTimeEarliest.month) + 1;
        if (monthOffset >= 1 && monthOffset <= barCount) {
          chartMinutes[monthOffset] = (chartMinutes[monthOffset] ?? 0) + log.duration.inMinutes;
        }
      }
    }

    final maxChartMinutes = chartMinutes.values.isEmpty
        ? 60
        : max(60, chartMinutes.values.reduce(max));

    // Group logs by date for list display
    final Map<String, List<ActivityLog>> groupedLogs = {};
    for (var log in categoryLogs) {
      final key = _formatDateHeader(log.startTime);
      groupedLogs.putIfAbsent(key, () => []).add(log);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Top Summary Card (Avatar Icon + Total Time + Daily Average)
          Container(
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
                  backgroundColor: widget.category.color,
                  child: Icon(widget.category.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          _formatDuration(totalDuration),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: widget.category.color,
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
                          '${_formatDuration(Duration(minutes: dailyAvgMinutes))}/d',
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
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Distribution Bar Chart Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _granularity == CategoryDetailGranularity.week
                      ? 'Weekly Distribution'
                      : (_granularity == CategoryDetailGranularity.year
                          ? 'Monthly Distribution'
                          : (_granularity == CategoryDetailGranularity.custom
                              ? 'Custom Period Distribution'
                              : (_granularity == CategoryDetailGranularity.all
                                  ? 'All Time Monthly Distribution'
                                  : 'Daily Distribution'))),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxChartMinutes.toDouble() * 1.1,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final mins = rod.toY.toInt();
                            String label = 'Day ${group.x}';
                            final shortMonths = [
                              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                            ];
                            if (_granularity == CategoryDetailGranularity.week) {
                              final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              if (group.x >= 1 && group.x <= 7) label = weekDays[group.x - 1];
                            } else if (_granularity == CategoryDetailGranularity.month) {
                              label = '${targetPeriodDate.month}/${group.x}';
                            } else if (_granularity == CategoryDetailGranularity.year) {
                              if (group.x >= 1 && group.x <= 12) label = shortMonths[group.x - 1];
                            } else if (_granularity == CategoryDetailGranularity.custom) {
                              final start = _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
                              final date = start.add(Duration(days: group.x - 1));
                              label = '${shortMonths[date.month - 1]} ${date.day}';
                            } else if (_granularity == CategoryDetailGranularity.all) {
                              final mDate = DateTime(allTimeEarliest.year, allTimeEarliest.month + (group.x - 1), 1);
                              label = '${shortMonths[mDate.month - 1]} ${mDate.year}';
                            }
                            return BarTooltipItem(
                              '$label\n${_formatDuration(Duration(minutes: mins))}',
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final x = value.toInt();
                              final shortMonths = [
                                'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                              ];
                              if (_granularity == CategoryDetailGranularity.week) {
                                final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                if (x >= 1 && x <= 7) {
                                  return Text(weekDays[x - 1],
                                      style: const TextStyle(color: Colors.grey, fontSize: 10));
                                }
                              } else if (_granularity == CategoryDetailGranularity.month) {
                                if (x == 1 || x == 7 || x == 14 || x == 21 || x == 28) {
                                  return Text(
                                    '${targetPeriodDate.month}/$x',
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  );
                                }
                              } else if (_granularity == CategoryDetailGranularity.year) {
                                final months = ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'];
                                if (x == 1 || x == 3 || x == 5 || x == 7 || x == 9 || x == 11) {
                                  final idx = (x - 1) ~/ 2;
                                  return Text(months[idx],
                                      style: const TextStyle(color: Colors.grey, fontSize: 10));
                                }
                              } else if (_granularity == CategoryDetailGranularity.custom) {
                                final start = _customDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
                                final date = start.add(Duration(days: x - 1));
                                int step = 1;
                                if (barCount > 60) {
                                  step = 15;
                                } else if (barCount > 20) {
                                  step = 5;
                                } else if (barCount > 10) {
                                  step = 3;
                                }
                                if ((x - 1) % step == 0 || x == barCount) {
                                  return Text(
                                    '${date.month}/${date.day}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  );
                                }
                              } else if (_granularity == CategoryDetailGranularity.all) {
                                final mDate = DateTime(allTimeEarliest.year, allTimeEarliest.month + (x - 1), 1);
                                int step = 1;
                                if (barCount > 36) {
                                  step = 12;
                                } else if (barCount > 18) {
                                  step = 3;
                                } else if (barCount > 6) {
                                  step = 2;
                                }
                                if ((x - 1) % step == 0 || x == barCount) {
                                  if (barCount > 36) {
                                    return Text('${mDate.year}', style: const TextStyle(color: Colors.grey, fontSize: 10));
                                  } else {
                                    return Text('${shortMonths[mDate.month - 1]} ${mDate.year.toString().substring(2)}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 10));
                                  }
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(barCount, (index) {
                        final x = index + 1;
                        final mins = chartMinutes[x] ?? 0;
                        return BarChartGroupData(
                          x: x,
                          barRods: [
                            BarChartRodData(
                              toY: mins.toDouble(),
                              color: mins > 0
                                  ? widget.category.color
                                  : Colors.grey.shade200,
                              width: barCount > 30 ? 4 : (barCount > 12 ? 6 : 14),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Spendee-style Labels Breakdown Card
          Builder(
            builder: (context) {
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
                          color: Colors.black87),
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
                              _formatDuration(Duration(minutes: totalMins)),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),

          // Grouped Activity Logs Section
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
                      padding: const EdgeInsets.only(
                          left: 4, top: 12, bottom: 6, right: 4),
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
                            _formatDuration(Duration(minutes: dayMins)),
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
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: List.generate(logs.length, (idx) {
                          final log = logs[idx];
                          final actEnd = log.endTime ??
                              log.startTime.add(const Duration(hours: 1));

                          BorderRadius itemRadius;
                          if (logs.length == 1) {
                            itemRadius = BorderRadius.circular(12);
                          } else if (idx == 0) {
                            itemRadius = const BorderRadius.vertical(
                                top: Radius.circular(12));
                          } else if (idx == logs.length - 1) {
                            itemRadius = const BorderRadius.vertical(
                                bottom: Radius.circular(12));
                          } else {
                            itemRadius = BorderRadius.zero;
                          }

                          return Column(
                            children: [
                              InkWell(
                                splashColor: widget.category.color.withValues(alpha: 0.2),
                                hoverColor: widget.category.color.withValues(alpha: 0.1),
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
                                        backgroundColor: widget.category.color,
                                        child: Icon(widget.category.icon,
                                            color: Colors.white, size: 18),
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
                                                  color: Colors.black87),
                                            ),
                                            if (log.description.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 3.0, bottom: 4.0),
                                                child: Text(
                                                  log.description,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54),
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
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        border: Border.all(
                                                            color: const Color(0xFF1A73E8)
                                                                .withValues(alpha: 0.3)),
                                                      ),
                                                      child: Text(
                                                        lbl,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF1A73E8)),
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
                                            _formatDuration(log.duration),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: widget.category.color,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_formatTimeOfDay(log.startTime)} - ${_formatTimeOfDay(actEnd)}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500),
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
      ),
    );
  }
}
