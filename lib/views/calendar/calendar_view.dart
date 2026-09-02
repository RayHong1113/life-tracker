import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../models/activity_category.dart';
import '../../providers/activity_provider.dart';
import 'add_activity_screen.dart';

class _PositionedActivity {
  final ActivityLog activity;
  int column = 0;
  int totalColumns = 1;

  _PositionedActivity(this.activity);
}

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  int? _selectedHour;
  bool _isFullHourSelected = false;

  static const int _basePageOffset = 10000;
  final DateTime _initialDate = DateTime.now();
  late final PageController _pageController =
      PageController(initialPage: _basePageOffset);

  bool _isAnimatingPage = false;
  double _currentScrollOffset = 0.0;

  // 💡 布局核心尺寸常量
  static const double _hourHeight = 70.0;           // 1小时对应的固定物理高度
  static const double _timeLabelWidth = 50.0;       // 左侧时间轴宽度
  static const double _cellHorizontalMargin = 2.0;  // 格子/卡片左右缩进 Margin

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getDateFromPageIndex(int index) {
    final dayDifference = index - _basePageOffset;
    return DateTime(
      _initialDate.year,
      _initialDate.month,
      _initialDate.day + dayDifference,
    );
  }

  int _getPageIndexFromDate(DateTime date) {
    final initialOnlyDate =
        DateTime(_initialDate.year, _initialDate.month, _initialDate.day);
    final targetOnlyDate = DateTime(date.year, date.month, date.day);
    final dayDifference = targetOnlyDate.difference(initialOnlyDate).inDays;
    return _basePageOffset + dayDifference;
  }

  void _animateToDate(DateTime targetDate, ActivityProvider provider) async {
    if (_isAnimatingPage) return;
    _isAnimatingPage = true;

    provider.setSelectedDate(targetDate);

    final targetPageIndex = _getPageIndexFromDate(targetDate);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        targetPageIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
    _isAnimatingPage = false;
  }

  void _safeDeleteActivity(ActivityProvider provider, ActivityLog activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: activity.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: activity.color,
                ),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.deleteActivity(activity.id);
    }
  }

  Future<void> _openAddOrEditActivityScreen(
    BuildContext context, {
    required DateTime selectedDate,
    int? initialHour,
    int? initialMinute,
    DateTime? initialStartTime,
    ActivityLog? existingActivity,
  }) async {
    DateTime? customStartTime = initialStartTime;
    if (customStartTime == null && initialHour != null) {
      customStartTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        initialHour,
        initialMinute ?? 0,
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          selectedDate: selectedDate,
          initialHour: initialHour,
          initialStartTime: customStartTime,
          existingActivity: existingActivity,
        ),
      ),
    );
  }

  /// 💡 关键辅助函数：计算给定 targetDate 和 hour 内被占用的最大分钟偏移量 (0~60)
  int _getOccupiedMinutesInHour(
      DateTime targetDate, int hour, List<ActivityLog> dayActivities) {
    int maxEndMinute = 0;

    final hourStart =
        DateTime(targetDate.year, targetDate.month, targetDate.day, hour, 0, 0);
    final hourEnd = DateTime(
        targetDate.year, targetDate.month, targetDate.day, hour, 59, 59);

    for (var activity in dayActivities) {
      final start = activity.startTime;
      final end = activity.endTime ?? start.add(const Duration(hours: 1));

      if (start.isBefore(hourEnd) && end.isAfter(hourStart)) {
        if (end.isAfter(hourEnd)) {
          maxEndMinute = 60;
        } else if (end.year == targetDate.year &&
            end.month == targetDate.month &&
            end.day == targetDate.day &&
            end.hour == hour) {
          if (end.minute > maxEndMinute) {
            maxEndMinute = end.minute;
          }
        }
      }
    }
    return maxEndMinute;
  }

  /// 💡 智能计算从 startHour 开始的最佳起始时间（处理整点全满及跨天任务）
  DateTime _getSmartStartTime(
      DateTime targetDate, int startHour, List<ActivityLog> dayActivities) {
    int currentHour = startHour;

    while (currentHour < 24) {
      final occupied =
          _getOccupiedMinutesInHour(targetDate, currentHour, dayActivities);
      if (occupied < 60) {
        return DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          currentHour,
          occupied,
        );
      }
      currentHour++;
    }

    final nextDay = targetDate.add(const Duration(days: 1));
    return DateTime(nextDay.year, nextDay.month, nextDay.day, 0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final selectedDate = provider.selectedDate;
    final targetPageIndex = _getPageIndexFromDate(selectedDate);

    if (_pageController.hasClients && !_isAnimatingPage) {
      final currentPage = _pageController.page?.round() ?? _basePageOffset;
      if (currentPage != targetPageIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && !_isAnimatingPage) {
            final curr = _pageController.page?.round() ?? _basePageOffset;
            if (curr != targetPageIndex) {
              _pageController.jumpToPage(targetPageIndex);
            }
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (pageIndex) {
            if (!_isAnimatingPage) {
              final newDate = _getDateFromPageIndex(pageIndex);
              provider.setSelectedDate(newDate);
            }
          },
          itemBuilder: (context, pageIndex) {
            final pageDate = _getDateFromPageIndex(pageIndex);

            final pageScrollController =
                ScrollController(initialScrollOffset: _currentScrollOffset);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (pageScrollController.hasClients &&
                  pageScrollController.offset != _currentScrollOffset) {
                pageScrollController.jumpTo(_currentScrollOffset);
              }
            });

            return Column(
              children: [
                _buildDateHeaderForPage(context, provider, pageDate),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final pageActivities = provider.getActivitiesForDateSync(pageDate);
                      final positionedActivities =
                          _calculateOverlapPositions(pageActivities);

                      return NotificationListener<ScrollNotification>(
                        onNotification: (scrollNotification) {
                          if (scrollNotification is ScrollUpdateNotification &&
                              scrollNotification.metrics.axis ==
                                  Axis.vertical) {
                            _currentScrollOffset =
                                scrollNotification.metrics.pixels;
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: pageScrollController,
                          padding: const EdgeInsets.only(top: 12.0, bottom: 24.0, left: 6.0, right: 6.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gridContentWidth = constraints.maxWidth - _timeLabelWidth;

                              return Stack(
                                children: [
                                  Column(
                                    children: List.generate(24, (hour) {
                                      return _buildFixedHourCell(hour, pageActivities, pageDate);
                                    }),
                                  ),
                                  ...positionedActivities.map((pos) {
                                    return _buildPositionedActivityCard(
                                      pos,
                                      provider,
                                      pageDate,
                                      gridContentWidth,
                                    );
                                  }),
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 2,
        backgroundColor: const Color(0xFF1A73E8),
        onPressed: () async {
          DateTime? smartStartTime;
          if (_selectedHour != null) {
            final currentActivities =
                await provider.getActivitiesForDate(selectedDate);
            if (_isFullHourSelected) {
              smartStartTime = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                _selectedHour!,
                0,
              );
            } else {
              smartStartTime = _getSmartStartTime(
                  selectedDate, _selectedHour!, currentActivities);
            }
          }

          if (context.mounted) {
            _openAddOrEditActivityScreen(
              context,
              selectedDate: selectedDate,
              initialHour: smartStartTime?.hour ?? _selectedHour,
              initialStartTime: smartStartTime,
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildDateHeaderForPage(
      BuildContext context, ActivityProvider provider, DateTime pageDate) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final dateString =
        '${weekDays[pageDate.weekday - 1]}, ${months[pageDate.month - 1]} ${pageDate.day}, ${pageDate.year}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: pageDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (pickedDate != null) {
                _animateToDate(pickedDate, provider);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Text(
                    dateString,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black54),
                ],
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prevDate = pageDate.subtract(const Duration(days: 1));
                  _animateToDate(prevDate, provider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  final nextDate = pageDate.add(const Duration(days: 1));
                  _animateToDate(nextDate, provider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_PositionedActivity> _calculateOverlapPositions(
      List<ActivityLog> activities) {
    if (activities.isEmpty) return [];

    final sorted = activities.map((a) => _PositionedActivity(a)).toList()
      ..sort((a, b) => a.activity.startTime.compareTo(b.activity.startTime));

    final groups = <List<_PositionedActivity>>[];
    List<_PositionedActivity> currentGroup = [];
    DateTime? groupEnd;

    for (var pos in sorted) {
      final start = pos.activity.startTime;
      final end = pos.activity.endTime ?? start.add(const Duration(hours: 1));

      if (currentGroup.isEmpty) {
        currentGroup.add(pos);
        groupEnd = end;
      } else if (start.isBefore(groupEnd!)) {
        currentGroup.add(pos);
        if (end.isAfter(groupEnd)) groupEnd = end;
      } else {
        groups.add(currentGroup);
        currentGroup = [pos];
        groupEnd = end;
      }
    }
    if (currentGroup.isNotEmpty) groups.add(currentGroup);

    for (var group in groups) {
      final List<DateTime> columnEndTimes = [];

      for (var pos in group) {
        final start = pos.activity.startTime;
        final end =
            pos.activity.endTime ?? start.add(const Duration(hours: 1));

        int assignedColumn = -1;

        for (int c = 0; c < columnEndTimes.length; c++) {
          if (!start.isBefore(columnEndTimes[c])) {
            assignedColumn = c;
            columnEndTimes[c] = end;
            break;
          }
        }

        if (assignedColumn == -1) {
          assignedColumn = columnEndTimes.length;
          columnEndTimes.add(end);
        }

        pos.column = assignedColumn;
      }

      final maxCols = columnEndTimes.length;
      for (var pos in group) {
        pos.totalColumns = maxCols;
      }
    }

    return sorted;
  }

  Widget _buildFixedHourCell(int hour, List<ActivityLog> pageActivities, DateTime pageDate) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final isSelected = _selectedHour == hour;

    final occupiedMinutes = _getOccupiedMinutesInHour(pageDate, hour, pageActivities);
    
    // 💡 关键：如果是全选模式或者没有占用，从 0 分钟开始；如果是点击右侧，从 occupiedMinutes 开始
    final startMinute = (isSelected && _isFullHourSelected) ? 0 : (occupiedMinutes < 60 ? occupiedMinutes : 0);

    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 💡 1. 左侧时间标尺：点击选择【整个小时段】
          SizedBox(
            width: _timeLabelWidth,
            child: InkWell(
              borderRadius: BorderRadius.circular(6.0),
              onTap: () {
                setState(() {
                  _selectedHour = hour;
                  _isFullHourSelected = true; // 👈 标记为全选整个小时
                });
              },
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
              onTap: () {
                setState(() {
                  _selectedHour = hour;
                  _isFullHourSelected = false; // 👈 标记为智能切分剩余时间段
                });
              },
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 1.0,
                      horizontal: _cellHorizontalMargin,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: Colors.grey.shade300, width: 1.0),
                    ),
                  ),
                  if (isSelected && (occupiedMinutes < 60 || _isFullHourSelected)) ...[
                    Positioned(
                      top: (startMinute / 60.0) * _hourHeight + 1.0,
                      bottom: 1.0,
                      left: _cellHorizontalMargin,
                      right: _cellHorizontalMargin,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: const Color(0xFF1A73E8),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        
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

  Widget _buildPositionedActivityCard(
    _PositionedActivity pos,
    ActivityProvider provider,
    DateTime pageDate,
    double gridContentWidth,
  ) {
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

    final double pixelsPerMinute = _hourHeight / 60.0;

    final double topOffset = (startMinutes * pixelsPerMinute) + 2.0;
    final double rawCardHeight = (durationMinutes * pixelsPerMinute) - 3.0;
    final double cardHeight = rawCardHeight.clamp(6.0, 1800.0);

    final double columnWidth = gridContentWidth / pos.totalColumns;
    final double leftOffset = _timeLabelWidth + (pos.column * columnWidth) + _cellHorizontalMargin;
    final double cardWidth = (columnWidth - (_cellHorizontalMargin * 2.0)).clamp(20.0, gridContentWidth);

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
            onTap: () {
              _openAddOrEditActivityScreen(
                context,
                selectedDate: provider.selectedDate,
                existingActivity: activity,
              );
            },
            child: Container(
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.only(left: 6.0, right: 1.5, top: 4.0, bottom: 2.0),
              child: cardHeight < 14.0 
                  ? const SizedBox.shrink()
                  : (cardWidth < 50.0
                      ? _buildCompactMicroLayout(activity, startTime, cardHeight, provider)
                      : (cardHeight < 36.0 
                          ? _buildSingleLineLayout(activity, startTime, endTime, cardWidth, provider)
                          : (useVerticalLayout
                              ? _buildVerticalLayout(activity, startTime, endTime, cardHeight, cardWidth, provider)
                              : _buildHorizontalLayout(activity, startTime, endTime, cardHeight, provider)))),
            ),
          ),
        ),
      ),
    );
  }

  ActivityCategory _getCategoryForActivity(
      ActivityLog activity, ActivityProvider provider) {
    final actTitle = activity.title.trim().toLowerCase();
    for (var cat in provider.categories) {
      if (cat.name.trim().toLowerCase() == actTitle) {
        return cat;
      }
    }

    IconData fallbackIcon = Icons.label_outline;
    if (actTitle.contains('code') || actTitle.contains('coding') || actTitle.contains('dev')) {
      fallbackIcon = Icons.code;
    } else if (actTitle.contains('work') || actTitle.contains('job')) {
      fallbackIcon = Icons.work_outline;
    } else if (actTitle.contains('study') || actTitle.contains('read') || actTitle.contains('book')) {
      fallbackIcon = Icons.school_outlined;
    } else if (actTitle.contains('workout') || actTitle.contains('gym') || actTitle.contains('fit') || actTitle.contains('sport')) {
      fallbackIcon = Icons.fitness_center;
    } else if (actTitle.contains('game') || actTitle.contains('play')) {
      fallbackIcon = Icons.sports_esports_outlined;
    } else if (actTitle.contains('cook') || actTitle.contains('food') || actTitle.contains('eat')) {
      fallbackIcon = Icons.restaurant;
    } else if (actTitle.contains('shop') || actTitle.contains('buy')) {
      fallbackIcon = Icons.shopping_bag_outlined;
    } else if (actTitle.contains('rest') || actTitle.contains('sleep') || actTitle.contains('nap')) {
      fallbackIcon = Icons.bedtime_outlined;
    }

    return ActivityCategory(
      id: '0',
      name: activity.title,
      icon: fallbackIcon,
      color: activity.color,
    );
  }

  Widget _buildCompactMicroLayout(
    ActivityLog activity,
    DateTime startTime,
    double cardHeight,
    ActivityProvider provider,
  ) {
    final category = _getCategoryForActivity(activity, provider);

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
              _formatTime(startTime),
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
    ActivityProvider provider,
  ) {
    final category = _getCategoryForActivity(activity, provider);
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
                    ? '${_formatTime(startTime)} - ${_formatTime(endTime)}'
                    : _formatTime(startTime),
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
          onTap: () => _safeDeleteActivity(provider, activity),
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
    ActivityProvider provider,
  ) {
    final category = _getCategoryForActivity(activity, provider);

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
                  '${_formatTime(startTime)} - ${_formatTime(endTime)}',
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
              onTap: () => _safeDeleteActivity(provider, activity),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
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
    ActivityProvider provider,
  ) {
    final category = _getCategoryForActivity(activity, provider);

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
              onTap: () => _safeDeleteActivity(provider, activity),
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
                  ? '${_formatTime(startTime)} - ${_formatTime(endTime)}'
                  : _formatTime(startTime),
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

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}