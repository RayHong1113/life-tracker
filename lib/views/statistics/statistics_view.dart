import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';
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
  TimeRange _selectedRange = TimeRange.byMonth;
  ChartMode _chartMode = ChartMode.loggedTime; // 默认：Logged Time

  static const int _basePageOffset = 10000;
  final PageController _pageController =
      PageController(initialPage: _basePageOffset);
  int _currentPageIndex = _basePageOffset;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 获取当前 Page 对应的基准时间
  DateTime _getAnchorDateForPage(int pageIndex) {
    final offset = pageIndex - _basePageOffset;
    final now = DateTime.now();

    if (_selectedRange == TimeRange.byDay) {
      return DateTime(now.year, now.month, now.day + offset);
    } else if (_selectedRange == TimeRange.byWeek) {
      return now.add(Duration(days: offset * 7));
    } else if (_selectedRange == TimeRange.byMonth) {
      return DateTime(now.year, now.month + offset, 1);
    } else if (_selectedRange == TimeRange.byYear) {
      return DateTime(now.year + offset, 1, 1);
    } else {
      return now;
    }
  }

  // 生成顶部日期标题
  String _getDateRangeTitle(DateTime anchorDate) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    if (_selectedRange == TimeRange.byDay) {
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekDays[anchorDate.weekday - 1]}, ${months[anchorDate.month - 1]} ${anchorDate.day}, ${anchorDate.year}';
    } else if (_selectedRange == TimeRange.byWeek) {
      final weekStart =
          anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      if (weekStart.month == weekEnd.month) {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${weekEnd.day}, ${weekStart.year}';
      } else {
        return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}, ${weekStart.year}';
      }
    } else if (_selectedRange == TimeRange.byMonth) {
      final fullMonths = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${fullMonths[anchorDate.month - 1]} ${anchorDate.year}';
    } else if (_selectedRange == TimeRange.byYear) {
      return '${anchorDate.year}';
    } else {
      return 'All Time History';
    }
  }

  // 计算固定客观总时长 (Objective Time)
  int _calculateObjectiveMinutes(DateTime anchorDate, List<ActivityLog> activities) {
    if (_selectedRange == TimeRange.byDay) {
      return 24 * 60; // 严格固定 24h (1440m)
    } else if (_selectedRange == TimeRange.byWeek) {
      return 7 * 24 * 60; // 严格固定 168h
    } else if (_selectedRange == TimeRange.byMonth) {
      final daysInMonth = DateTime(anchorDate.year, anchorDate.month + 1, 0).day;
      return daysInMonth * 24 * 60;
    } else if (_selectedRange == TimeRange.byYear) {
      final isLeapYear = (anchorDate.year % 4 == 0 && anchorDate.year % 100 != 0) || (anchorDate.year % 400 == 0);
      return (isLeapYear ? 366 : 365) * 24 * 60;
    } else {
      if (activities.isEmpty) return 24 * 60;
      final earliest = activities.map((a) => a.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      final days = DateTime.now().difference(earliest).inDays + 1;
      return days * 24 * 60;
    }
  }

  // 统计逻辑
  Map<String, _CategoryStats> _calculateStatsForPage(
      List<ActivityLog> activities,
      List<ActivityCategory> categories,
      DateTime anchorDate) {
    final Map<String, _CategoryStats> statsMap = {};

    DateTime? windowStart;
    DateTime? windowEnd;

    if (_selectedRange == TimeRange.byDay) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, anchorDate.day, 0, 0, 0);
      windowEnd = windowStart.add(const Duration(days: 1));
    } else if (_selectedRange == TimeRange.byWeek) {
      final weekStart =
          anchorDate.subtract(Duration(days: anchorDate.weekday - 1));
      windowStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
      windowEnd = windowStart.add(const Duration(days: 7));
    } else if (_selectedRange == TimeRange.byMonth) {
      windowStart = DateTime(anchorDate.year, anchorDate.month, 1);
      windowEnd = DateTime(anchorDate.year, anchorDate.month + 1, 1);
    } else if (_selectedRange == TimeRange.byYear) {
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
        (cat) =>
            cat.name.toLowerCase() == activity.title.toLowerCase() ||
            cat.color.toARGB32() == activity.color.toARGB32(),
        orElse: () => ActivityCategory(
          id: 'default',
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
    final activities = provider.activities;
    final categories = provider.categories;

    final currentAnchorDate = _getAnchorDateForPage(_currentPageIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Overview',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              children: [
                // 1. 顶部时间维度可滑动按钮
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildTimeRangeButton(TimeRange.byDay, 'By Day'),
                      const SizedBox(width: 8),
                      _buildTimeRangeButton(TimeRange.byWeek, 'By Week'),
                      const SizedBox(width: 8),
                      _buildTimeRangeButton(TimeRange.byMonth, 'By Month'),
                      const SizedBox(width: 8),
                      _buildTimeRangeButton(TimeRange.byYear, 'By Year'),
                      const SizedBox(width: 8),
                      _buildTimeRangeButton(TimeRange.all, 'All Time'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 2. 日期翻页与标题
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: _selectedRange == TimeRange.all
                            ? Colors.black26
                            : Colors.black87,
                      ),
                      onPressed: _selectedRange == TimeRange.all
                          ? null
                          : () {
                              if (_pageController.hasClients) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                    ),
                    Text(
                      _getDateRangeTitle(currentAnchorDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: _selectedRange == TimeRange.all
                            ? Colors.black26
                            : Colors.black87,
                      ),
                      onPressed: _selectedRange == TimeRange.all
                          ? null
                          : () {
                              if (_pageController.hasClients) {
                                _pageController.nextPage(
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
              controller: _pageController,
              physics: _selectedRange == TimeRange.all
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              itemBuilder: (context, pageIndex) {
                final pageAnchorDate = _getAnchorDateForPage(pageIndex);
                final statsMap = _calculateStatsForPage(
                    activities, categories, pageAnchorDate);
                final statsList = statsMap.values.toList()
                  ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

                final totalMinutesAll = statsList.fold<int>(
                    0, (sum, item) => sum + item.totalDuration.inMinutes);
                
                final objectiveMinutes = _calculateObjectiveMinutes(pageAnchorDate, activities);
                final denominator = _chartMode == ChartMode.objectiveTime
                    ? objectiveMinutes
                    : (totalMinutesAll > 0 ? totalMinutesAll : 1);

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3. 统计汇总 Card
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
                                        Duration(minutes: totalMinutesAll)),
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
                                    '${statsList.fold<int>(0, (sum, i) => sum + i.count)}',
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
                                _buildModeToggleBtn('Logged Time', ChartMode.loggedTime),
                                _buildModeToggleBtn('Objective Time', ChartMode.objectiveTime),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (statsList.isEmpty)
                        Container(
                          height: 180,
                          alignment: Alignment.center,
                          child: const Text(
                            'No activity logs found for this period.',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        )
                      else ...[
                        // 💡 双视图智能切换：Logged Time 选饼图，Objective Time 选树状进度条
                        if (_chartMode == ChartMode.loggedTime)
                          _buildRadialDonutChart(statsList, totalMinutesAll, denominator)
                        else
                          _buildObjectiveTimeBars(statsList, totalMinutesAll, objectiveMinutes),

                        const SizedBox(height: 16),

                        // 5. 分类明细列表
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: statsList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final stat = statsList[index];
                            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 12.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: stat.category.color,
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
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${stat.count} session${stat.count > 1 ? 's' : ''} • ${percentage.toStringAsFixed(1)}%',
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(stat.totalDuration),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
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
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]
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

  // 💡 客观时间 - 树状/柱状占比图 (Objective Time Progress Bars)
  Widget _buildObjectiveTimeBars(
      List<_CategoryStats> statsList, int totalMinutesAll, int objectiveMinutes) {
    final unloggedMinutes = max(0, objectiveMinutes - totalMinutesAll);
    final totalLoggedPct = (totalMinutesAll / objectiveMinutes) * 100;

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
                'Logged ${_formatDuration(Duration(minutes: totalMinutesAll))} of ${_formatDuration(Duration(minutes: objectiveMinutes))}',
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
              final barRatio = (stat.totalDuration.inMinutes / objectiveMinutes).clamp(0.0, 1.0);

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

  // 💡 已记录时间 - 饼图视图 (Donut Chart)
  Widget _buildRadialDonutChart(
      List<_CategoryStats> statsList, int totalMinutesAll, int denominator) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center =
              Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          const donutOuterRadius = 66.0;
          const lineLength = 24.0;

          // 过滤占比 >= 1% 的分类生成引线
          final visibleStats = statsList.where((stat) {
            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;
            return percentage >= 1.0; 
          }).toList();

          double currentAngle = -90.0;
          List<double> rawAngles = [];

          for (var stat in statsList) {
            final sweep = (stat.totalDuration.inMinutes /
                    (totalMinutesAll > 0 ? totalMinutesAll : 1)) *
                360.0;
            
            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;

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

            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;

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

  Widget _buildTimeRangeButton(TimeRange range, String label) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () {
        if (_selectedRange != range) {
          setState(() {
            _selectedRange = range;
            _currentPageIndex = _basePageOffset;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(_basePageOffset);
            }
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A73E8) : Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A73E8) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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