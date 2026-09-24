import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';
import 'add_activity_screen.dart';
import 'utils/timeline_layout_helper.dart';
import 'widgets/calendar_date_header.dart';
import 'widgets/timeline_hour_cell.dart';
import 'widgets/activity_card_cell.dart';

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

  void _safeDeleteActivity(
      ActivityProvider provider, ActivityLog activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text.rich(
          TextSpan(
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: Colors.black87),
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
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                CalendarDateHeader(
                  pageDate: pageDate,
                  onDateSelected: (newDate) =>
                      _animateToDate(newDate, provider),
                  onPrevDay: () {
                    final prevDate =
                        pageDate.subtract(const Duration(days: 1));
                    _animateToDate(prevDate, provider);
                  },
                  onNextDay: () {
                    final nextDate = pageDate.add(const Duration(days: 1));
                    _animateToDate(nextDate, provider);
                  },
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final pageActivities =
                          provider.getActivitiesForDateSync(pageDate);
                      final positionedActivities =
                          TimelineLayoutHelper.calculateOverlapPositions(
                              pageActivities);

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
                          padding: const EdgeInsets.only(
                              top: 12.0, bottom: 24.0, left: 6.0, right: 6.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gridContentWidth = constraints.maxWidth -
                                  TimelineLayoutHelper.timeLabelWidth;

                              return Stack(
                                children: [
                                  Column(
                                    children: List.generate(24, (hour) {
                                      return TimelineHourCell(
                                        hour: hour,
                                        pageActivities: pageActivities,
                                        pageDate: pageDate,
                                        selectedHour: _selectedHour,
                                        isFullHourSelected:
                                            _isFullHourSelected,
                                        onSelectFullHour: () {
                                          setState(() {
                                            _selectedHour = hour;
                                            _isFullHourSelected = true;
                                          });
                                        },
                                        onSelectRemainingSlot: () {
                                          setState(() {
                                            _selectedHour = hour;
                                            _isFullHourSelected = false;
                                          });
                                        },
                                      );
                                    }),
                                  ),
                                  ...positionedActivities.map((pos) {
                                    return ActivityCardCell(
                                      pos: pos,
                                      pageDate: pageDate,
                                      gridContentWidth: gridContentWidth,
                                      categories: provider.categories,
                                      onTap: () {
                                        _openAddOrEditActivityScreen(
                                          context,
                                          selectedDate: provider.selectedDate,
                                          existingActivity: pos.activity,
                                        );
                                      },
                                      onDelete: () => _safeDeleteActivity(
                                          provider, pos.activity),
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
              smartStartTime = TimelineLayoutHelper.getSmartStartTime(
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
}