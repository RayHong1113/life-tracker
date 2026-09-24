import 'package:flutter/material.dart';

class CalendarDateHeader extends StatelessWidget {
  final DateTime pageDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevDay;
  final VoidCallback onNextDay;

  const CalendarDateHeader({
    super.key,
    required this.pageDate,
    required this.onDateSelected,
    required this.onPrevDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
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
                onDateSelected(pickedDate);
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
                onPressed: onPrevDay,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextDay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
