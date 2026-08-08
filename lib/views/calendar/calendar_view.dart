import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
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

  void _openAddOrEditActivityScreen(
    BuildContext context, {
    required DateTime selectedDate,
    int? initialHour,
    int? initialMinute,
    ActivityLog? existingActivity,
  }) {
    DateTime? customStartTime;
    if (initialHour != null) {
      customStartTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        initialHour,
        initialMinute ?? 0,
      );
    }

    Navigator.push(
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

  /// 💡 关键辅助函数：计算给定 hour 内被占用的最大分钟偏移量 (0~60)
  int _getOccupiedMinutesInHour(int hour, List<ActivityLog> dayActivities) {
    int maxEndMinute = 0;

    for (var activity in dayActivities) {
      final start = activity.startTime;
      final end = activity.endTime ?? start.add(const Duration(hours: 1));

      final hourStart = DateTime(start.year, start.month, start.day, hour, 0);
      final hourEnd = DateTime(start.year, start.month, start.day, hour, 59, 59);

      if (start.isBefore(hourEnd) && end.isAfter(hourStart)) {
        if (end.hour > hour) {
          maxEndMinute = 60;
        } else if (end.hour == hour) {
          if (end.minute > maxEndMinute) {
            maxEndMinute = end.minute;
          }
        }
      }
    }
    return maxEndMinute;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final selectedDate = provider.selectedDate;

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
                  child: FutureBuilder<List<ActivityLog>>(
                    future: provider.getActivitiesForDate(pageDate),
                    builder: (context, snapshot) {
                      final pageActivities = snapshot.data ?? [];
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
                                      return _buildFixedHourCell(hour, pageActivities);
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
          int? minuteOffset;
          if (_selectedHour != null) {
            final currentActivities = await provider.getActivitiesForDate(selectedDate);
            final occupied = _getOccupiedMinutesInHour(_selectedHour!, currentActivities);
            minuteOffset = occupied < 60 ? occupied : 0;
          }

          if (context.mounted) {
            _openAddOrEditActivityScreen(
              context,
              selectedDate: selectedDate,
              initialHour: _selectedHour,
              initialMinute: minuteOffset,
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

  Widget _buildFixedHourCell(int hour, List<ActivityLog> pageActivities) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final isSelected = _selectedHour == hour;

    final occupiedMinutes = _getOccupiedMinutesInHour(hour, pageActivities);
    
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

    final bool useVerticalLayout = cardWidth < 80.0 || pos.totalColumns > 2;

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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 3.0, 
                vertical: cardHeight < 12.0 ? 0.0 : 1.0
              ),
              child: cardHeight < 14.0 
                  ? const SizedBox.shrink()
                  : (cardHeight < 38.0 
                      ? _buildSingleLineLayout(activity, startTime, endTime, provider)
                      : (useVerticalLayout
                          ? _buildVerticalLayout(activity, startTime, endTime, cardHeight, provider)
                          : _buildHorizontalLayout(activity, startTime, endTime, cardHeight, provider))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleLineLayout(
    ActivityLog activity,
    DateTime startTime,
    DateTime endTime,
    ActivityProvider provider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: activity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                TextSpan(
                  text: '       ${_formatTime(startTime)} - ${_formatTime(endTime)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.normal,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
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
              if (cardHeight > 38.0)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: Text(
                    '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _safeDeleteActivity(provider, activity),
          child: const Icon(
            Icons.close,
            size: 13,
            color: Colors.white70,
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
    ActivityProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                activity.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            GestureDetector(
              onTap: () => _safeDeleteActivity(provider, activity),
              child: const Icon(
                Icons.close,
                size: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        if (cardHeight > 32.0) ...[
          const SizedBox(height: 1),
          Text(
            _formatTime(startTime),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (cardHeight > 46.0)
            Text(
              '- ${_formatTime(endTime)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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