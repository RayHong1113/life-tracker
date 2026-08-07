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

  static const int _basePageOffset = 10000;
  final DateTime _initialDate = DateTime.now();
  late final PageController _pageController =
      PageController(initialPage: _basePageOffset);

  bool _isAnimatingPage = false;
  double _currentScrollOffset = 0.0;

  static const double _hourHeight = 70.0;
  static const double _timeLabelWidth = 50.0;

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

  void _safeDeleteActivity(ActivityProvider provider, String id) async {
    await provider.deleteActivity(id);
  }

  void _openAddOrEditActivityScreen(BuildContext context,
      {required DateTime selectedDate,
      int? initialHour,
      ActivityLog? existingActivity}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          selectedDate: selectedDate,
          initialHour: initialHour,
          existingActivity: existingActivity,
        ),
      ),
    );
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 10.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final availableWidth = constraints.maxWidth -
                                  _timeLabelWidth -
                                  4.0;

                              return Stack(
                                children: [
                                  Column(
                                    children: List.generate(24, (hour) {
                                      return _buildFixedHourCell(hour);
                                    }),
                                  ),
                                  ...positionedActivities.map((pos) {
                                    return _buildPositionedActivityCard(
                                      pos,
                                      provider,
                                      pageDate,
                                      availableWidth,
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
        onPressed: () => _openAddOrEditActivityScreen(context,
            selectedDate: selectedDate, initialHour: _selectedHour),
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

  // 💡 升级后的 Google Calendar 风格最小列占用并排重叠算法
  List<_PositionedActivity> _calculateOverlapPositions(
      List<ActivityLog> activities) {
    if (activities.isEmpty) return [];

    final sorted = activities.map((a) => _PositionedActivity(a)).toList()
      ..sort((a, b) => a.activity.startTime.compareTo(b.activity.startTime));

    final groups = <List<_PositionedActivity>>[];
    List<_PositionedActivity> currentGroup = [];
    DateTime? groupEnd;

    // 1. 划分有时间重叠交叉的大块 Group
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

    // 2. 贪心算法：给重叠组内的活动分配紧凑列号（Column Index）
    for (var group in groups) {
      final List<DateTime> columnEndTimes = [];

      for (var pos in group) {
        final start = pos.activity.startTime;
        final end =
            pos.activity.endTime ?? start.add(const Duration(hours: 1));

        int assignedColumn = -1;

        // 判断是否有已存在的列可以顺着接下去
        for (int c = 0; c < columnEndTimes.length; c++) {
          if (!start.isBefore(columnEndTimes[c])) {
            assignedColumn = c;
            columnEndTimes[c] = end;
            break;
          }
        }

        // 如果现有列都冲突，开辟新列
        if (assignedColumn == -1) {
          assignedColumn = columnEndTimes.length;
          columnEndTimes.add(end);
        }

        pos.column = assignedColumn;
      }

      // 将该重叠组的最大并发列数赋给属于该组的所有活动
      final maxCols = columnEndTimes.length;
      for (var pos in group) {
        pos.totalColumns = maxCols;
      }
    }

    return sorted;
  }

  Widget _buildFixedHourCell(int hour) {
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    final isSelected = _selectedHour == hour;

    return SizedBox(
      height: _hourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timeLabelWidth,
            child: Padding(
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
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedHour = hour;
                });
              },
              child: Container(
                margin:
                    const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1A73E8)
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: isSelected && _providerActivitiesIsEmpty()
                    ? Text(
                        'Tap + to add task at $formattedHour $amPm',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF1A73E8)),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _providerActivitiesIsEmpty() {
    return Provider.of<ActivityProvider>(context, listen: false)
        .activities
        .isEmpty;
  }

  Widget _buildPositionedActivityCard(
    _PositionedActivity pos,
    ActivityProvider provider,
    DateTime pageDate,
    double availableWidth,
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

    final double topOffset = startMinutes * pixelsPerMinute;

    final double rawCardHeight = (durationMinutes * pixelsPerMinute) - 2.0;
    // 💡 这里的 22.0 可以根据你的需求调整最小卡片高度
    final double cardHeight = rawCardHeight.clamp(22.0, 1800.0);

    final columnWidth = availableWidth / pos.totalColumns;
    final leftOffset = _timeLabelWidth + (pos.column * columnWidth) + 2.0;
    final cardWidth = (columnWidth - 4.0).clamp(30.0, availableWidth);

    // 💡 关键判断：如果卡片宽度小于 80px，或者因为重叠列数太多（totalColumns > 2），自动切换为竖向布局！
    final bool useVerticalLayout = cardWidth < 80.0 || pos.totalColumns > 2;

    return Positioned(
      top: topOffset + 1.0,
      left: leftOffset,
      width: cardWidth,
      height: cardHeight,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(6.0),
        color: activity.color,
        child: InkWell(
          borderRadius: BorderRadius.circular(6.0),
          onTap: () {
            _openAddOrEditActivityScreen(
              context,
              selectedDate: provider.selectedDate,
              existingActivity: activity,
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: useVerticalLayout
                ? _buildVerticalLayout(activity, startTime, endTime, cardHeight, provider)
                : _buildHorizontalLayout(activity, startTime, endTime, cardHeight, provider),
          ),
        ),
      ),
    );
  }

  // 💡 1. 横向布局 (宽卡片)
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
              if (cardHeight > 45.0)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
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
          onTap: () => _safeDeleteActivity(provider, activity.id),
          child: const Icon(
            Icons.close,
            size: 13,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  // 💡 2. 竖向布局 (窄卡片/重叠较多时)
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
              onTap: () => _safeDeleteActivity(provider, activity.id),
              child: const Icon(
                Icons.close,
                size: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        // 如果卡片高度足够，把持续时间换行摆在下方
        if (cardHeight > 35.0) ...[
          const SizedBox(height: 2),
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
          if (cardHeight > 50.0)
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