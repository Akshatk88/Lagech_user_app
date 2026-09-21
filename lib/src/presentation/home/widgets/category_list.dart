import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';

class CategoryList extends StatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<String>? onCategorySelected;
  final String selectedCategoryName;

  const CategoryList({
    super.key,
    required this.categories,
    this.onCategorySelected,
    this.selectedCategoryName = 'All',
  });

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seenIds = <String>{};
    final seenNames = <String>{};
    final uniqueCategories = <CategoryModel>[];

    for (final c in widget.categories) {
      final idKey = c.id.trim();
      final nameKey = c.name.trim().toLowerCase();

      final isDuplicateId = idKey.isNotEmpty && seenIds.contains(idKey);
      final isDuplicateName = nameKey.isNotEmpty && seenNames.contains(nameKey);

      if (isDuplicateId || isDuplicateName) continue;

      if (idKey.isNotEmpty) seenIds.add(idKey);
      if (nameKey.isNotEmpty) seenNames.add(nameKey);
      uniqueCategories.add(c);
    }

    final items = uniqueCategories.map((c) => {'name': c.name, 'imageUrl': c.imageUrl, 'category': c}).toList();

    return SizedBox(
      height: 84.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final cat = items[index];
          final name = cat['name'] as String;
          // Selection state is removed since this is now just for navigation

          return GestureDetector(
            onTap: () {
              Haptics.light();
              widget.onCategorySelected?.call(name);
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60.w,
                    height: 60.h,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: ClipOval(
                      child: SmartImage(
                        url: cat['imageUrl'] as String,
                        category: ImageCategory.category,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  SizedBox(
                    width: 64.w,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
