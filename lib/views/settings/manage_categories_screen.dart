import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import 'category_form_screen.dart'; // 💡 导入刚才新建的表单页面
import '../../models/activity_category.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  // 💡 跳转到全新的全屏表单页面
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
                        onPressed: () {
                          if (categories.length > 1) {
                            provider.deleteCategory(category.id);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'At least one category is required.')),
                            );
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