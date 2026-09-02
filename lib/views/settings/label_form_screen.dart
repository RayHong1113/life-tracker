import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_label.dart';
import '../../providers/activity_provider.dart';

class LabelFormScreen extends StatefulWidget {
  final ActivityCategoryLabel? existingLabel;

  const LabelFormScreen({super.key, this.existingLabel});

  @override
  State<LabelFormScreen> createState() => _LabelFormScreenState();
}

class _LabelFormScreenState extends State<LabelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingLabel?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<ActivityProvider>(context, listen: false);
      final labelName = _nameController.text.trim();

      if (widget.existingLabel != null) {
        final updatedLabel = ActivityCategoryLabel(
          id: widget.existingLabel!.id,
          name: labelName,
          sortOrder: widget.existingLabel!.sortOrder,
        );
        await provider.updateLabel(updatedLabel);
      } else {
        final newLabel = ActivityCategoryLabel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: labelName,
        );
        await provider.addLabel(newLabel);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingLabel != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Label' : 'Add New Label'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Chip Header
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1A73E8), width: 1.2),
                  ),
                  child: Text(
                    _nameController.text.isEmpty ? '🏷️ Label Preview' : _nameController.text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Name Input
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Label Name / Emoji',
                  hintText: 'e.g. ✍️ Writing, 🚶 Walking, 🏋️ Dumbbell',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a label name or emoji';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Tip: You can type Emojis directly using your phone or computer keyboard!',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Create Label',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
