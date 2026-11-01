import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_detail_types.dart';
import '../utils/category_detail_helper.dart';

/// Distribution bar chart widget displaying time breakdown by days or months.
class CategoryDetailBarChart extends StatelessWidget {
  final CategoryDetailGranularity granularity;
  final Color categoryColor;
  final DateTime targetPeriodDate;
  final DateTime allTimeEarliest;
  final DateTimeRange? customDateRange;
  final Map<int, int> chartMinutes;
  final int barCount;
  final int maxChartMinutes;

  const CategoryDetailBarChart({
    super.key,
    required this.granularity,
    required this.categoryColor,
    required this.targetPeriodDate,
    required this.allTimeEarliest,
    required this.customDateRange,
    required this.chartMinutes,
    required this.barCount,
    required this.maxChartMinutes,
  });

  String _getChartTitle() {
    switch (granularity) {
      case CategoryDetailGranularity.week:
        return 'Weekly Distribution';
      case CategoryDetailGranularity.month:
        return 'Daily Distribution';
      case CategoryDetailGranularity.year:
        return 'Monthly Distribution';
      case CategoryDetailGranularity.custom:
        return 'Custom Period Distribution';
      case CategoryDetailGranularity.all:
        return 'All Time Monthly Distribution';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            _getChartTitle(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
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

                      if (granularity == CategoryDetailGranularity.week) {
                        final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (group.x >= 1 && group.x <= 7) label = weekDays[group.x - 1];
                      } else if (granularity == CategoryDetailGranularity.month) {
                        label = '${targetPeriodDate.month}/${group.x}';
                      } else if (granularity == CategoryDetailGranularity.year) {
                        if (group.x >= 1 && group.x <= 12) label = shortMonths[group.x - 1];
                      } else if (granularity == CategoryDetailGranularity.custom) {
                        final now = DateTime.now();
                        final start = customDateRange?.start ??
                            DateTime(now.year, now.month, now.day - 30);
                        final date = DateTime(start.year, start.month, start.day + (group.x - 1));
                        label = '${shortMonths[date.month - 1]} ${date.day}';
                      } else if (granularity == CategoryDetailGranularity.all) {
                        final mDate = DateTime(
                            allTimeEarliest.year, allTimeEarliest.month + (group.x - 1), 1);
                        label = '${shortMonths[mDate.month - 1]} ${mDate.year}';
                      }
                      return BarTooltipItem(
                        '$label\n${CategoryDetailHelper.formatDuration(Duration(minutes: mins))}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final x = value.toInt();
                        final shortMonths = [
                          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                        ];

                        if (granularity == CategoryDetailGranularity.week) {
                          final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          if (x >= 1 && x <= 7) {
                            return Text(weekDays[x - 1],
                                style: const TextStyle(color: Colors.grey, fontSize: 10));
                          }
                        } else if (granularity == CategoryDetailGranularity.month) {
                          if (x == 1 || x == 7 || x == 14 || x == 21 || x == 28) {
                            return Text(
                              '${targetPeriodDate.month}/$x',
                              style: const TextStyle(color: Colors.grey, fontSize: 10),
                            );
                          }
                        } else if (granularity == CategoryDetailGranularity.year) {
                          final months = ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'];
                          if (x == 1 || x == 3 || x == 5 || x == 7 || x == 9 || x == 11) {
                            final idx = (x - 1) ~/ 2;
                            return Text(months[idx],
                                style: const TextStyle(color: Colors.grey, fontSize: 10));
                          }
                        } else if (granularity == CategoryDetailGranularity.custom) {
                          final now = DateTime.now();
                          final start = customDateRange?.start ??
                              DateTime(now.year, now.month, now.day - 30);
                          final date = DateTime(start.year, start.month, start.day + (x - 1));
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
                        } else if (granularity == CategoryDetailGranularity.all) {
                          final mDate = DateTime(
                              allTimeEarliest.year, allTimeEarliest.month + (x - 1), 1);
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
                              return Text('${mDate.year}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 10));
                            } else {
                              return Text(
                                '${shortMonths[mDate.month - 1]} ${mDate.year.toString().substring(2)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              );
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
                        color: mins > 0 ? categoryColor : Colors.grey.shade200,
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
    );
  }
}
