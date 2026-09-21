import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(40.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0.w, vertical: 8.0.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home (Branch 0)
              _buildNavItem(
                context: context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: l10n.home,
                index: 0,
                isDark: isDark,
              ),

              // 2. Search (reusing Branch 1 or route)
              _buildNavItem(
                context: context,
                icon: Icons.search_outlined,
                activeIcon: Icons.search_rounded,
                label: 'Search',
                index: 1, // assuming branch 1 is search or handled separately
                isDark: isDark,
              ),

              // 3. Orders (Route /orders)
              _buildNavItem(
                context: context,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: l10n.orders,
                index: 99,
                isDark: isDark,
              ),

              // 4. Profile (Branch 3)
              _buildNavItem(
                context: context,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: l10n.profile,
                index: 3,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    // Current route checking for index 99 (Orders) or 1 (Search) if they are pushed instead of branched
    final isSelected = currentIndex == index;
    final activeColor = const Color(0xFF38019D); // Dark purple from mockup
    final unselectedColor = Colors.grey.shade500;
    
    // Background for active item (light purple)
    final activeBgColor = const Color(0xFFF3E8FF); 

    return GestureDetector(
      onTap: () {
        Haptics.light();
        if (index == 99) {
          context.push(RouteNames.orders);
        } else if (index == 1) {
          context.push(RouteNames.search);
        } else {
          onTap(index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16.w : 12.w, 
          vertical: 10.h,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : unselectedColor,
              size: 24.sp,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : unselectedColor,
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
