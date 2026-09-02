import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import 'category_form_screen.dart';
import '../../models/activity_category.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  void _navigateToForm(BuildContext context, {ActivityCategory? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormScreen(existingCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ActivityProvider>(context);
    final categories = provider.categories;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Manage Categories',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: categories.length,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
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
          provider.reorderCategories(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            key: ValueKey(category.id),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8.0),
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle,
                        color: Colors.grey, size: 22),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: category.color,
                    child: Icon(category.icon, color: Colors.white, size: 20),
                  ),
                ],
              ),
              title: Text(category.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.grey, size: 20),
                    onPressed: () =>
                        _navigateToForm(context, category: category),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 20),
                    onPressed: () async {
                      if (categories.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('At least one category is required.')),
                        );
                        return;
                      }

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete Category?'),
                          content: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Colors.black87),
                              children: [
                                const TextSpan(text: 'By deleting '),
                                TextSpan(
                                  text: category.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: category.color),
                                ),
                                const TextSpan(
                                    text:
                                        ', all activity logs recorded under this category will also be permanently deleted.'),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent),
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Delete',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await provider.deleteCategory(category.id);
                      }
                    },
                  ),
                ],
              ),
            ),
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
                'Add New Category',
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