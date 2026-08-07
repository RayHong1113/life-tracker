import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';

class AddActivityScreen extends StatefulWidget {
  final DateTime selectedDate;
  final int? initialHour;
  final ActivityLog? existingActivity;

  const AddActivityScreen({
    super.key,
    required this.selectedDate,
    this.initialHour,
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
    final targetHour = widget.initialHour ?? DateTime.now().hour;

    _notesController = TextEditingController(
        text: isEditing ? widget.existingActivity!.description : '');

    _startDate = isEditing ? widget.existingActivity!.startTime : widget.selectedDate;
    _startTimeOfDay = isEditing
        ? TimeOfDay.fromDateTime(widget.existingActivity!.startTime)
        : TimeOfDay(hour: targetHour, minute: 0);

    _endDate = isEditing
        ? (widget.existingActivity!.endTime ?? _startDate.add(const Duration(hours: 1)))
        : _startDate;
    _endTimeOfDay = isEditing
        ? TimeOfDay.fromDateTime(widget.existingActivity!.endTime ??
            widget.existingActivity!.startTime.add(const Duration(hours: 1)))
        : TimeOfDay(hour: (targetHour + 1) % 24, minute: 0);
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

  // 💡 改为 async 函数，增加 await 保证数据库写完盘再退出
  void _saveActivity(List<ActivityCategory> categories) async {
    final category = _selectedCategory ?? categories[0];

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTimeOfDay.hour,
      _startTimeOfDay.minute,
    );

    // 1. 先按选中的日期和时间组合
    DateTime endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTimeOfDay.hour,
      _endTimeOfDay.minute,
    );

    // 💡 2. 关键修复：如果结束时间早于或等于开始时间（比如选了 midnight 00:00），说明跨天了，自动给结束时间 +1 天！
    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
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

    _selectedCategory ??= categories.firstWhere(
      (cat) => isEditing && (cat.name == widget.existingActivity!.title || cat.color.toARGB32() == widget.existingActivity!.color.toARGB32()),
      orElse: () => categories[0],
    );

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
                                        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                                      });
                                    }
                                  },
                                  child: Text(_formatDate(_startDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final time = await _pickTime(_startTimeOfDay);
                                    if (time != null) setState(() => _startTimeOfDay = time);
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
                                      initialDate: _endDate,
                                      firstDate: _startDate,
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) setState(() => _endDate = picked);
                                  },
                                  child: Text(_formatDate(_endDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: () async {
                                    final time = await _pickTime(_endTimeOfDay);
                                    if (time != null) setState(() => _endTimeOfDay = time);
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