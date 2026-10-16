import 'package:flutter/material.dart';
import '../models/category_stats.dart';

/// Segmented toggle button row for switching between Logged Time and Objective Time chart modes.
class StatisticsModeToggle extends StatelessWidget {
  final ChartMode currentMode;
  final ValueChanged<ChartMode> onModeChanged;

  const StatisticsModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  Widget _buildToggleOption(String label, ChartMode mode) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Row(
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
              _buildToggleOption('Logged Time', ChartMode.loggedTime),
              _buildToggleOption('Objective Time', ChartMode.objectiveTime),
            ],
          ),
        ),
      ],
    );
  }
}
