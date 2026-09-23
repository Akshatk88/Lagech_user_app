import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';

class CategoryList extends StatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<String>? onCategorySelected;
  final VoidCallback? onMealsUnder200Tap;
  final String selectedCategoryName;

  const CategoryList({
    super.key,
    required this.categories,
    this.onCategorySelected,
    this.onMealsUnder200Tap,
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

    // Curate order: biryani, cake, chhole, chicken, donuts, pizza, burger, etc.
    const firstPrefixes = ['biryani', 'cake', 'chhole', 'chicken', 'donut', 'pizza', 'burger', 'sandwich', 'momo'];
    const lastPrefixes = ['frozen', 'bakery', 'sauce', 'toast'];

    final firstItems = <CategoryModel>[];
    final lastItems = <CategoryModel>[];
    final middleItems = <CategoryModel>[];

    for (final prefix in firstPrefixes) {
      final matches = uniqueCategories
          .where((c) =>
              c.name.toLowerCase().contains(prefix) &&
              !firstItems.contains(c))
          .toList();
      firstItems.addAll(matches);
    }

    for (final prefix in lastPrefixes) {
      final matches = uniqueCategories
          .where((c) =>
              c.name.toLowerCase().contains(prefix) &&
              !firstItems.contains(c) &&
              !lastItems.contains(c))
          .toList();
      lastItems.addAll(matches);
    }

    for (final c in uniqueCategories) {
      if (!firstItems.contains(c) && !lastItems.contains(c)) {
        middleItems.add(c);
      }
    }

    final orderedCategories = [...firstItems, ...middleItems, ...lastItems];
    final items = orderedCategories
        .map((c) => {'name': c.name, 'imageUrl': c.imageUrl, 'category': c})
        .toList();

    return SizedBox(
      height: 104.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: items.length + 1, // +1 for the leading "MEALS UNDER ₹200" badge
        itemBuilder: (context, index) {
          // Index 0: MEALS UNDER ₹200 Badge
          if (index == 0) {
            return GestureDetector(
              onTap: () {
                Haptics.light();
                widget.onMealsUnder200Tap?.call();
              },
              child: Container(
                width: 66.w,
                margin: EdgeInsets.only(right: 12.w, top: 4.h, bottom: 4.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E3A8A), // Deep Navy Blue
                      Color(0xFF1D4ED8),
                      Color(0xFF2563EB),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Colors.white70,
                      size: 14.sp,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'MEALS\nUNDER\n₹200',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 10.sp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Remaining: Circular Food Categories
          final cat = items[index - 1];
          final name = cat['name'] as String;

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
                    height: 60.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                    width: 66.w,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
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
