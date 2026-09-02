import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_label.dart';
import '../../providers/activity_provider.dart';
import 'label_form_screen.dart';

class ManageLabelsScreen extends StatelessWidget {
  const ManageLabelsScreen({super.key});

  Future<void> _navigateToForm(BuildContext context, [ActivityCategoryLabel? label]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LabelFormScreen(existingLabel: label),
      ),
    );
    if (result == true && context.mounted) {
      Provider.of<ActivityProvider>(context, listen: false).fetchLabels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Labels'),
        centerTitle: true,
      ),
      body: Consumer<ActivityProvider>(
        builder: (context, provider, child) {
          final labels = provider.labels;

          if (labels.isEmpty) {
            return const Center(
              child: Text(
                'No labels created yet.\nTap below to add your first label!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
            itemCount: labels.length,
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  return Material(
                    elevation: 4,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              provider.reorderLabels(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final label = labels[index];
              return Container(
                key: ValueKey(label.id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1A73E8).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      label.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                        onPressed: () => _navigateToForm(context, label),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete Label?'),
                              content: Text('Are you sure you want to delete "${label.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await provider.deleteLabel(label.id);
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToForm(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 22),
              label: const Text(
                'Add New Label',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
