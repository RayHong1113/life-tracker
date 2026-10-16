import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category_stats.dart';

/// Radial line painter connecting the donut pie slices to external category percentage indicators.
class RadialLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  RadialLinePainter({
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

/// Circular donut chart with external indicator badges and percentage labels.
class StatisticsDonutChart extends StatelessWidget {
  final List<CategoryStats> statsList;
  final int totalMinutesActive;
  final int denominator;

  const StatisticsDonutChart({
    super.key,
    required this.statsList,
    required this.totalMinutesActive,
    required this.denominator,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
          const donutOuterRadius = 66.0;
          const lineLength = 24.0;

          final visibleStats = statsList.where((stat) {
            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;
            return percentage >= 1.0;
          }).toList();

          double currentAngle = -90.0;
          final List<double> rawAngles = [];

          for (var stat in statsList) {
            final sweep = (stat.totalDuration.inMinutes /
                    (totalMinutesActive > 0 ? totalMinutesActive : 1)) *
                360.0;

            final percentage = (stat.totalDuration.inMinutes / denominator) * 100;
            if (percentage >= 1.0) {
              rawAngles.add(currentAngle + sweep / 2.0);
            }
            currentAngle += sweep;
          }

          final List<double> adjustedAngles = List.from(rawAngles);
          const minAngleGap = 18.0;

          if (adjustedAngles.length > 1) {
            for (int pass = 0; pass < 3; pass++) {
              for (int i = 0; i < adjustedAngles.length - 1; i++) {
                final double diff = adjustedAngles[i + 1] - adjustedAngles[i];
                if (diff < minAngleGap) {
                  final double overlap = minAngleGap - diff;
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
                painter: RadialLinePainter(
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
