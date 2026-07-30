import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_log.dart';
import '../../providers/activity_provider.dart';

/// The primary screen displaying the list of recorded time-blocked activities.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Tracker'),
        centerTitle: true,
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.activities.isEmpty) {
            return const Center(
              child: Text(
                'No activity logs yet.\nTap + to track your time!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.activities.length,
            padding: const EdgeInsets.all(12.0),
            itemBuilder: (context, index) {
              final activity = provider.activities[index];
              return _buildActivityTile(context, activity, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddActivityDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Track Activity'),
      ),
    );
  }

  /// Builds an individual activity card showing title, time range, and duration.
  Widget _buildActivityTile(
      BuildContext context, ActivityLog activity, ActivityProvider provider) {
    final startTimeStr =
        '${activity.startTime.hour.toString().padLeft(2, '0')}:${activity.startTime.minute.toString().padLeft(2, '0')}';
    
    final endTimeStr = activity.endTime != null
        ? '${activity.endTime!.hour.toString().padLeft(2, '0')}:${activity.endTime!.minute.toString().padLeft(2, '0')}'
        : 'Ongoing';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.access_time),
        ),
        title: Text(
          activity.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$startTimeStr - $endTimeStr\n${activity.description}'),
        isThreeLine: activity.description.isNotEmpty,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => provider.deleteActivity(activity.id),
        ),
      ),
    );
  }

  /// Shows a modal dialog to input new activity details.
  void _showAddActivityDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Time Log'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'What did you do?',
                  hintText: 'e.g., Coding Flutter, Work shift',
                ),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final newActivity = ActivityLog(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    startTime: DateTime.now(),
                    endTime: DateTime.now().add(const Duration(hours: 1)),
                    description: descriptionController.text.trim(),
                  );

                  Provider.of<ActivityProvider>(context, listen: false)
                      .addActivity(newActivity);

                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}