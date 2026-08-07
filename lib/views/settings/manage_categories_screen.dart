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
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.color,
                    child: Icon(category.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(category.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.grey, size: 20),
                        onPressed: () => _navigateToForm(context, category: category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          // 1. 如果只剩最后一个分类，不允许删除，弹底栏提示
                          if (categories.length <= 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'At least one category is required.')),
                            );
                            return;
                          }

                          // 💡 2. 只有多个分类时，先弹出对话框警告！
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Delete Category?'),
                              content: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
                                  children: [
                                    const TextSpan(text: 'By deleting '),
                                    TextSpan(
                                      text: category.name, // 💡 分类名字单独加粗
                                      style: TextStyle(fontWeight: FontWeight.bold, color: category.color),
                                    ),
                                    const TextSpan(text: ', all activity logs recorded under this category will also be permanently deleted.'),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );

                          // 💡 3. 只有用户在弹窗里点击了 Delete (confirm == true)，才执行删除
                          if (confirm == true) {
                            await provider.deleteCategory(category.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A73E8),
        onPressed: () => _navigateToForm(context),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}