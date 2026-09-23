import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';

class HomeFilterChipsRow extends StatelessWidget {
  final VoidCallback onFiltersTap;
  final VoidCallback? onUnder30MinsTap;
  final VoidCallback? onUnder45MinsTap;
  final VoidCallback? onUnder1KmTap;
  final String? activeFilter;

  const HomeFilterChipsRow({
    super.key,
    required this.onFiltersTap,
    this.onUnder30MinsTap,
    this.onUnder45MinsTap,
    this.onUnder1KmTap,
    this.activeFilter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // 1. Filters Button
          _buildChip(
            isDark: isDark,
            icon: Icons.tune_rounded,
            label: 'Filters',
            isSelected: false,
            onTap: () {
              Haptics.light();
              onFiltersTap();
            },
          ),
          SizedBox(width: 8.w),

          // 2. Under 30 mins
          _buildChip(
            isDark: isDark,
            label: 'Under 30 mins',
            isSelected: activeFilter == '30mins',
            onTap: () {
              Haptics.light();
              onUnder30MinsTap?.call();
            },
          ),
          SizedBox(width: 8.w),

          // 3. Under 45 mins
          _buildChip(
            isDark: isDark,
            label: 'Under 45 mins',
            isSelected: activeFilter == '45mins',
            onTap: () {
              Haptics.light();
              onUnder45MinsTap?.call();
            },
          ),
          SizedBox(width: 8.w),

          // 4. Under 1km
          _buildChip(
            isDark: isDark,
            icon: Icons.location_on_outlined,
            label: 'Under 1km',
            isSelected: activeFilter == '1km',
            onTap: () {
              Haptics.light();
              onUnder1KmTap?.call();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required bool isDark,
    IconData? icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.12)
        : (isDark ? AppColors.surfaceDark : Colors.white);

    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB));

    final textColor = isSelected
        ? AppColors.primary
        : (isDark ? Colors.white : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isDark || isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15.sp,
                color: textColor,
              ),
              SizedBox(width: 5.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
