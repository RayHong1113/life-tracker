import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import '../../models/activity_category.dart';

class CategoryFormScreen extends StatefulWidget {
  final ActivityCategory? existingCategory;

  const CategoryFormScreen({super.key, this.existingCategory});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  late final TextEditingController _nameController;

  late IconData _selectedIcon;
  late Color _selectedColor;

  // 常用分类图标库
  static const List<IconData> _availableIcons = [
    Icons.directions_car_outlined,
    Icons.flight,
    Icons.restaurant,
    Icons.person_outline,
    Icons.payments_outlined,
    Icons.theater_comedy_outlined,
    Icons.home_outlined,
    Icons.flash_on,
    Icons.shopping_bag_outlined,
    Icons.bedtime_outlined,
    Icons.medical_services_outlined,
    Icons.card_giftcard,
    Icons.checkroom,
    Icons.train_outlined,
    Icons.nights_stay_outlined,
    Icons.local_bar,
    Icons.sports_soccer,
    Icons.pets,
    Icons.school_outlined,
    Icons.sports_esports_outlined,
    Icons.favorite_border,
    Icons.directions_subway_outlined,
    Icons.house_siding_outlined,
    Icons.music_note_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.redeem,
    Icons.info_outline,
    Icons.attach_money,
    Icons.fitness_center,
    Icons.phone_android,
    Icons.coffee_outlined,
    Icons.local_gas_station_outlined,
    Icons.speed,
    Icons.local_offer_outlined,
    Icons.bar_chart,
    Icons.book_outlined,
    Icons.play_arrow_outlined,
    Icons.build_outlined,
    Icons.two_wheeler,
    Icons.widgets_outlined,
  ];

  // 💡 大幅扩充后的色彩调色板（包含红、橙、黄、绿、青、蓝、紫、粉、棕、灰等多元色系）
  static const List<Color> _availableColors = [
    // 红色系
    Color(0xFFE53935), // 鲜红
    Color(0xFFD84315), // 赤红
    Color(0xFFC2185B), // 玫瑰红
    
    // 橙棕系
    Color(0xFFE65100), // 深橙
    Color(0xFFF57C00), // 活力橙
    Color(0xFFC07028), // 暖棕
    Color(0xFF8D6E63), // 咖啡棕
    
    // 黄色系
    Color(0xFFFFA000), // 琥珀黄
    Color(0xFFFFB300), // 金黄
    Color(0xFFFFC107), // 亮黄
    
    // 绿色系
    Color(0xFF188038), // 森林绿
    Color(0xFF43A047), // 草地绿
    Color(0xFF7CB342), // 苹果绿
    Color(0xFF00897B), // 墨绿/松石绿
    
    // 蓝青系
    Color(0xFF00ACC1), // 青色
    Color(0xFF039BE5), // 湖蓝
    Color(0xFF1A73E8), // 经典蓝
    Color(0xFF3949AB), // 靛青蓝
    
    // 紫粉系
    Color(0xFFA142F4), // 罗兰紫
    Color(0xFF8E24AA), // 葡萄紫
    Color(0xFFE52592), // 荧光粉
    Color(0xFFEC407A), // 珊瑚粉
    
    // 高级灰色系
    Color(0xFF607D8B), // 蓝灰
    Color(0xFF546E7A), // 板岩灰
    Color(0xFF424242), // 暗灰
  ];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.existingCategory != null;
    _nameController = TextEditingController(
        text: isEditing ? widget.existingCategory!.name : '');
    _selectedIcon =
        isEditing ? widget.existingCategory!.icon : _availableIcons[0];
    _selectedColor =
        isEditing ? widget.existingCategory!.color : _availableColors[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    final isEditing = widget.existingCategory != null;

    if (isEditing) {
      provider.updateCategory(ActivityCategory(
        id: widget.existingCategory!.id,
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
      ));
    } else {
      provider.addCategory(ActivityCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
      ));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCategory != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Category' : 'Create a New Category',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  // 1. 顶部预览 Circle + Category Name 输入框
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedColor,
                        ),
                        child: Icon(
                          _selectedIcon,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: 'Category name',
                            hintStyle:
                                TextStyle(color: Colors.black38, fontSize: 18),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF1A73E8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // 2. Category Color 选色器（未选中为白底小圆点，选中完全填满）
                  const Text(
                    'Category color',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _availableColors.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final color = _availableColors[index];
                        final isSelected = _selectedColor == color;

                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? color : Colors.white,
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: Colors.grey.shade300, width: 1),
                              boxShadow: [
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? null
                                : Center(
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. Category Icon 网格图标库
                  const Text(
                    'Category icon',
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                    ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = _availableIcons[index];
                      final isSelected = _selectedIcon == icon;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = icon),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? _selectedColor
                                : const Color(0xFFE9ECEF),
                          ),
                          child: Icon(
                            icon,
                            color: isSelected ? Colors.white : Colors.black87,
                            size: 26,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),

            // 4. 底部 Save 胶囊按钮
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _saveCategory,
                  child: Text(
                    isEditing ? 'Update Category' : 'Create a Category',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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