import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../models/activity_category.dart';
import '../../providers/activity_provider.dart';
import '../settings/manage_labels_screen.dart';

class AddActivityScreen extends StatefulWidget {
  final DateTime selectedDate;
  final int? initialHour;
  final DateTime? initialStartTime;
  final ActivityLog? existingActivity;

  const AddActivityScreen({
    super.key,
    required this.selectedDate,
    this.initialHour,
    this.initialStartTime,
    this.existingActivity,
  });

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  late final TextEditingController _notesController;

  late DateTime _startDate;
  late TimeOfDay _startTimeOfDay;
  late DateTime _endDate;
  late TimeOfDay _endTimeOfDay;

  ActivityCategory? _selectedCategory;
  final Set<String> _selectedLabelNames = {};

  @override
  void initState() {
    super.initState();
    final isEditing = widget.existingActivity != null;
    final now = DateTime.now();

    _notesController = TextEditingController(
        text: isEditing ? widget.existingActivity!.description : '');

    if (isEditing) {
      final activity = widget.existingActivity!;
      _startDate = DateTime(
        activity.startTime.year,
        activity.startTime.month,
        activity.startTime.day,
      );
      _startTimeOfDay = TimeOfDay.fromDateTime(activity.startTime);

      final end = activity.endTime ??
          DateTime(
            activity.startTime.year,
            activity.startTime.month,
            activity.startTime.day,
            activity.startTime.hour + 1,
            activity.startTime.minute,
          );
      _endDate = DateTime(end.year, end.month, end.day);
      _endTimeOfDay = TimeOfDay.fromDateTime(end);

      _selectedLabelNames.addAll(activity.labelNames);
      if (activity.labelName != null && activity.labelName!.isNotEmpty) {
        _selectedLabelNames.add(activity.labelName!);
      }
    } else {
      final baseDate = widget.initialStartTime != null
          ? DateTime(
              widget.initialStartTime!.year,
              widget.initialStartTime!.month,
              widget.initialStartTime!.day,
            )
          : DateTime(
              widget.selectedDate.year,
              widget.selectedDate.month,
              widget.selectedDate.day,
            );

      final isToday = now.year == baseDate.year &&
          now.month == baseDate.month &&
          now.day == baseDate.day;

      _startDate = baseDate;

      if (isToday) {
        final targetHour =
            widget.initialStartTime?.hour ?? widget.initialHour ?? now.hour;
        final targetMinute = widget.initialStartTime?.minute ?? now.minute;

        _startTimeOfDay = TimeOfDay(hour: targetHour, minute: targetMinute);
        _endDate = baseDate;
        _endTimeOfDay = TimeOfDay.fromDateTime(now);
      } else {
        final targetHour =
            widget.initialStartTime?.hour ?? widget.initialHour ?? 9;
        final targetMinute = widget.initialStartTime?.minute ?? 0;

        _startTimeOfDay = TimeOfDay(hour: targetHour, minute: targetMinute);
        _endDate = baseDate;
        _endTimeOfDay = TimeOfDay(
            hour: (_startTimeOfDay.hour + 1) % 24,
            minute: _startTimeOfDay.minute);
      }

      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTimeOfDay.hour,
        _startTimeOfDay.minute,
      );

      final endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTimeOfDay.hour,
        _endTimeOfDay.minute,
      );

      if (endDateTime.isBefore(startDateTime)) {
        final adjustedEnd = DateTime(
          startDateTime.year,
          startDateTime.month,
          startDateTime.day,
          startDateTime.hour + 1,
          startDateTime.minute,
        );
        _endDate =
            DateTime(adjustedEnd.year, adjustedEnd.month, adjustedEnd.day);
        _endTimeOfDay = TimeOfDay.fromDateTime(adjustedEnd);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) async {
    return await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
  }

  /// Displays a compact floating SnackBar notification.
  void _showLightSnackBar(String message) {
    if (!mounted) return;
    
    // Clear previous SnackBar to avoid stacking notifications on rapid clicks
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 2.0,
        backgroundColor: const Color(0xFF323F4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveActivity(List<ActivityCategory> categories) async {
    if (categories.isEmpty) return;
    
    final category = _selectedCategory ?? categories[0];

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTimeOfDay.hour,
      _startTimeOfDay.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTimeOfDay.hour,
      _endTimeOfDay.minute,
    );

    // Validate time order before saving
    if (endDateTime.isBefore(startDateTime)) {
      _showLightSnackBar('End time cannot be earlier than start time');
      return;
    }

    final isEditing = widget.existingActivity != null;
    final firstLabel = _selectedLabelNames.isNotEmpty ? _selectedLabelNames.first : null;

    final activity = ActivityLog(
      id: isEditing
          ? widget.existingActivity!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      title: category.name,
      startTime: startDateTime,
      endTime: endDateTime,
      description: _notesController.text.trim(),
      color: category.color,
      labelId: firstLabel,
      labelName: firstLabel,
      labelNames: _selectedLabelNames.toList(),
    );

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    if (isEditing) {
      provider.updateActivity(activity);
    } else {
      provider.addActivity(activity);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = Provider.of<ActivityProvider>(context, listen: false);
      await provider.deleteActivity(widget.existingActivity!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final categories = provider.categories;

    final isEditing = widget.existingActivity != null;

    if (categories.isNotEmpty) {
      _selectedCategory ??= categories.firstWhere(
        (cat) => isEditing && (cat.name == widget.existingActivity!.title || cat.color.toARGB32() == widget.existingActivity!.color.toARGB32()),
        orElse: () => categories[0],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E262C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E262C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Activity' : 'Add Activity',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Activity',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: const Color(0xFF263238),
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
                            title: const Text('Start', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _startDate = DateTime(picked.year, picked.month, picked.day);
                                        if (_endDate.isBefore(_startDate)) {
                                          _endDate = _startDate;
                                        }
                                      });
                                    }
                                  },
                                  child: Text(_formatDate(_startDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final time = await _pickTime(_startTimeOfDay);
                                    if (time != null) {
                                      setState(() {
                                        _startTimeOfDay = time;
                                      });
                                    }
                                  },
                                  child: Text(_startTimeOfDay.format(context), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white12, indent: 50),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.stop_circle_outlined, color: Colors.white70, size: 20),
                            title: const Text('End', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                                      firstDate: _startDate,
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
                                    }
                                  },
                                  child: Text(_formatDate(_endDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final time = await _pickTime(_endTimeOfDay);
                                    if (time != null) {
                                      final newEndDT = DateTime(_endDate.year, _endDate.month, _endDate.day, time.hour, time.minute);
                                      final startDT = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTimeOfDay.hour, _startTimeOfDay.minute);

                                      if (newEndDT.isBefore(startDT)) {
                                        _showLightSnackBar('End time cannot be earlier than start time');
                                        return;
                                      }

                                      setState(() => _endTimeOfDay = time);
                                    }
                                  },
                                  child: Text(_endTimeOfDay.format(context), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white12, indent: 50),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.edit_note_outlined, color: Colors.white70, size: 20),
                            title: TextField(
                              controller: _notesController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Write a note...',
                                hintStyle: TextStyle(color: Colors.white38),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Labels Header + Horizontal Multi-Select Chips
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageLabelsScreen(),
                          ),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_offer,
                                    color: Color(0xFF00E676), size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Labels',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.chevron_right,
                                color: Colors.white54, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: provider.labels.map((label) {
                          final isSelected =
                              _selectedLabelNames.contains(label.name);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedLabelNames.remove(label.name);
                                  } else {
                                    _selectedLabelNames.add(label.name);
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00C853)
                                      : const Color(0xFF2C353D),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(Icons.check,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      label.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Select Category',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategory?.id == category.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? category.color : const Color(0xFF263238),
                                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                ),
                                child: Icon(category.icon, color: Colors.white, size: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                category.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  onPressed: () => _saveActivity(categories),
                  child: Text(
                    isEditing ? 'Update Activity' : 'Save Activity',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
