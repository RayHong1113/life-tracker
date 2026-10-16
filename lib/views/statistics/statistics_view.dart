import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/settings_provider.dart';
import 'category_detail_screen.dart';
import 'models/category_stats.dart';
import 'utils/statistics_calculator.dart';
import 'widgets/statistics_header.dart';
import 'widgets/statistics_summary_card.dart';
import 'widgets/statistics_mode_toggle.dart';
import 'widgets/statistics_donut_chart.dart';
import 'widgets/statistics_objective_bars.dart';
import 'widgets/statistics_category_list.dart';

// Re-export models for backwards compatibility with existing imports.
export 'models/category_stats.dart';

/// Main statistics overview view presenting aggregated activity metrics, donut/bar charts, and category breakdowns.
class StatisticsView extends StatefulWidget {
  const StatisticsView({super.key});

  @override
  State<StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<StatisticsView> {
  ChartMode _chartMode = ChartMode.loggedTime;

  // Set of category names hidden from charts and aggregate metrics
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    final selectedRange = settingsProvider.timeRange;
    final calendarDate = provider.selectedDate;
    final activities = provider.activities;
    final categories = provider.categories;

    // Retrieve active period anchors that contain logged records or current date
    final availablePeriods = StatisticsCalculator.getAvailablePeriods(
      activities,
      selectedRange,
      calendarDate,
      _lastCalendarDate,
    );

    final targetAnchor = StatisticsCalculator.getPeriodAnchor(calendarDate, selectedRange);
    int matchedIdx = availablePeriods.indexWhere((p) => p == targetAnchor);
    if (matchedIdx == -1) {
      final nowAnchor = StatisticsCalculator.getPeriodAnchor(DateTime.now(), selectedRange);
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
            // Top Overview Header & Date Navigator
            StatisticsHeader(
              selectedRange: selectedRange,
              currentAnchorDate: currentAnchorDate,
              availablePeriods: availablePeriods,
              currentIndex: _currentIndex,
              onRangeSelected: (range) => settingsProvider.setTimeRange(range),
              onPreviousPressed: (selectedRange == TimeRange.all || _currentIndex <= 0)
                  ? null
                  : () {
                      if (_pageController != null && _pageController!.hasClients) {
                        _pageController!.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
              onNextPressed: (selectedRange == TimeRange.all || _currentIndex >= availablePeriods.length - 1)
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

            // Horizontal Swipeable PageView for Periods
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
                  final statsMap = StatisticsCalculator.calculateStatsForPage(
                    activities,
                    categories,
                    pageAnchorDate,
                    selectedRange,
                  );

                  final allStatsList = statsMap.values.toList()
                    ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));

                  // Filter out categories hidden by user
                  final activeStatsList = allStatsList
                      .where((s) => !_hiddenCategoryNames.contains(s.category.name))
                      .toList();

                  final totalMinutesActive = activeStatsList.fold<int>(
                    0,
                    (sum, item) => sum + item.totalDuration.inMinutes,
                  );
                  final totalSessionsActive = activeStatsList.fold<int>(
                    0,
                    (sum, item) => sum + item.count,
                  );

                  final objectiveMinutes = StatisticsCalculator.calculateObjectiveMinutes(
                    pageAnchorDate,
                    selectedRange,
                    activities,
                  );

                  final denominator = _chartMode == ChartMode.objectiveTime
                      ? objectiveMinutes
                      : (totalMinutesActive > 0 ? totalMinutesActive : 1);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Card (Total Time & Activity Sessions)
                        StatisticsSummaryCard(
                          totalMinutesActive: totalMinutesActive,
                          totalSessionsActive: totalSessionsActive,
                        ),
                        const SizedBox(height: 20),

                        // Categories Header & Chart Mode Toggle
                        StatisticsModeToggle(
                          currentMode: _chartMode,
                          onModeChanged: (mode) => setState(() => _chartMode = mode),
                        ),
                        const SizedBox(height: 12),

                        // Empty State vs Active Visual Charts
                        if (allStatsList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 36.0,
                              horizontal: 16.0,
                            ),
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
                                  'No Activity Logs for This Period',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
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
                            StatisticsDonutChart(
                              statsList: activeStatsList,
                              totalMinutesActive: totalMinutesActive,
                              denominator: denominator,
                            )
                          else
                            StatisticsObjectiveBars(
                              statsList: activeStatsList,
                              totalMinutesActive: totalMinutesActive,
                              objectiveMinutes: objectiveMinutes,
                            ),

                          const SizedBox(height: 16),

                          // Ranked Category Detail Breakdown List
                          StatisticsCategoryList(
                            allStatsList: allStatsList,
                            hiddenCategoryNames: _hiddenCategoryNames,
                            denominator: denominator,
                            onToggleVisibility: (catName) {
                              setState(() {
                                if (_hiddenCategoryNames.contains(catName)) {
                                  _hiddenCategoryNames.remove(catName);
                                } else {
                                  _hiddenCategoryNames.add(catName);
                                }
                              });
                            },
                            onCategoryTapped: (stat) {
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
}