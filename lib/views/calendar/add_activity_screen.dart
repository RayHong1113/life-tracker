import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../models/activity_category.dart';
import '../../providers/activity_provider.dart';

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

  @override
  void initState() {
    super.initState();
    final isEditing = widget.existingActivity != null;
    final now = DateTime.now();

    _notesController = TextEditingController(
        text: isEditing ? widget.existingActivity!.description : '');

    if (isEditing) {
      final activity = widget.existingActivity!;
      _startDate = activity.startTime;
      _startTimeOfDay = TimeOfDay.fromDateTime(activity.startTime);

      final end = activity.endTime ?? activity.startTime.add(const Duration(hours: 1));
      _endDate = end;
      _endTimeOfDay = TimeOfDay.fromDateTime(end);
    } else {
      final targetHour = widget.initialHour ?? now.hour;
      final targetMinute = widget.initialStartTime?.minute ?? 0;

      _startDate = widget.selectedDate;
      _startTimeOfDay = TimeOfDay(hour: targetHour, minute: targetMinute);

      _endDate = DateTime(now.year, now.month, now.day);
      _endTimeOfDay = TimeOfDay.fromDateTime(now);

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
        final adjustedEnd = startDateTime.add(const Duration(minutes: 15));
        _endDate = DateTime(adjustedEnd.year, adjustedEnd.month, adjustedEnd.day);
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

  /// 💡 低调小巧的精致 SnackBar 提示框
  void _showLightSnackBar(String message) {
    if (!mounted) return;
    
    // 先清理上一次的提示，防止快速点击时排队弹窗
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
        behavior: SnackBarBehavior.floating, // 💡 1. 悬浮模式（非拉满全宽）
        elevation: 2.0,
        backgroundColor: const Color(0xFF323F4B), // 💡 2. 柔和不刺眼的深灰蓝底色
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0), // 💡 3. 圆角胶囊形状
        ),
        margin: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 16.0), // 💡 4. 左右缩进，显得精致小巧
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

    // 保存前的合法性判定
    if (endDateTime.isBefore(startDateTime)) {
      _showLightSnackBar('End time cannot be earlier than start time');
      return;
    }

    final isEditing = widget.existingActivity != null;
    final activity = ActivityLog(
      id: isEditing
          ? widget.existingActivity!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      title: category.name,
      startTime: startDateTime,
      endTime: endDateTime,
      description: _notesController.text.trim(),
      color: category.color,
    );

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    if (isEditing) {
      await provider.updateActivity(activity);
    } else {
      await provider.addActivity(activity);
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
                                        _startDate = picked;
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
                                      setState(() => _endDate = picked);
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