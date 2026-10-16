import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// Screen allowing users to manage excluded/untracked dates that should not be counted
/// towards daily average calculations in statistics.
class ManageExcludedDaysScreen extends StatelessWidget {
  const ManageExcludedDaysScreen({super.key});

  /// Formats 'YYYY-MM-DD' key into a readable label (e.g. 'Thu, Oct 15, 2026')
  String _formatDisplayDate(String key) {
    try {
      final parts = key.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final dt = DateTime(year, month, day);
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        final weekday = weekdays[dt.weekday - 1];
        final monthStr = months[month - 1];
        return '$weekday, $monthStr $day, $year';
      }
    } catch (_) {}
    return key;
  }

  /// Displays date picker dialog to add a single untracked date
  Future<void> _pickSingleDate(BuildContext context, SettingsProvider provider) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'SELECT UNTRACKED DATE TO EXCLUDE',
    );

    if (picked != null && context.mounted) {
      final added = await provider.addExcludedDate(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? 'Excluded ${_formatDisplayDate(SettingsProvider.formatDateKey(picked))}'
                  : 'This date is already excluded.',
            ),
            backgroundColor: added ? const Color(0xFF188038) : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Displays date range picker dialog to add a sequence of untracked dates
  Future<void> _pickDateRange(BuildContext context, SettingsProvider provider) async {
    final now = DateTime.now();
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 1)),
        end: now,
      ),
      helpText: 'SELECT UNTRACKED DATE RANGE TO EXCLUDE',
    );

    if (pickedRange != null && context.mounted) {
      final count = await provider.addExcludedDateRange(
        pickedRange.start,
        pickedRange.end,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $count untracked date(s) to excluded list.'),
            backgroundColor: const Color(0xFF188038),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Confirms and clears all excluded dates
  Future<void> _confirmClearAll(BuildContext context, SettingsProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Excluded Dates?'),
        content: const Text(
          'This will remove all untracked dates from the exclusion list and include them back in daily average calculations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.clearAllExcludedDates();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All excluded dates have been cleared.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, provider, child) {
        final excludedList = provider.excludedDates.toList()
          ..sort((a, b) => b.compareTo(a));

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text(
              'Excluded Days (Untracked)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (excludedList.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  tooltip: 'Clear All',
                  onPressed: () => _confirmClearAll(context, provider),
                ),
            ],
          ),
          body: Column(
            children: [
              // Information banner card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1A73E8), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Days listed here are treated as untracked. They are subtracted from the total days in period when computing your Daily Average in statistics, keeping averages accurate even if you forgot to log.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF174EA6),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _pickSingleDate(context, provider),
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: const Text('Add Single Date', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDateRange(context, provider),
                        icon: const Icon(Icons.date_range_outlined, size: 18),
                        label: const Text('Add Date Range', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A73E8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFF1A73E8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 16),

              // Excluded dates list / empty state
              Expanded(
                child: excludedList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No untracked days excluded yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap above to add days you forgot to track.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: excludedList.length,
                        itemBuilder: (context, index) {
                          final key = excludedList[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFCE8E6),
                                child: Icon(
                                  Icons.event_busy,
                                  color: Color(0xFFD93025),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                _formatDisplayDate(key),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                tooltip: 'Remove Exclusion',
                                onPressed: () async {
                                  await provider.removeExcludedDate(key);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${_formatDisplayDate(key)} removed from excluded days',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
