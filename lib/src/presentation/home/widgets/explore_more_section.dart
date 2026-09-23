import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';

class ExploreMoreSection extends StatelessWidget {
  final VoidCallback onOffersTap;
  final VoidCallback onGourmetTap;
  final VoidCallback onTop10Tap;
  final VoidCallback onCollectionsTap;

  const ExploreMoreSection({
    super.key,
    required this.onOffersTap,
    required this.onGourmetTap,
    required this.onTop10Tap,
    required this.onCollectionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title: EXPLORE MORE
          Text(
            'EXPLORE MORE',
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 12.h),

          // 4 Grid/Row Items
          Row(
            children: [
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  label: 'Offers',
                  bgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFEBF3FC),
                  iconWidget: _buildOffersIcon(),
                  onTap: () {
                    Haptics.light();
                    onOffersTap();
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  label: 'Gourmet',
                  bgColor: isDark ? const Color(0xFF262626) : const Color(0xFFF7F2EB),
                  iconWidget: _buildGourmetIcon(),
                  onTap: () {
                    Haptics.light();
                    onGourmetTap();
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  label: 'Top 10',
                  bgColor: isDark ? const Color(0xFF2D2719) : const Color(0xFFFDF7E7),
                  iconWidget: _buildTop10Icon(),
                  onTap: () {
                    Haptics.light();
                    onTop10Tap();
                  },
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _buildExploreCard(
                  isDark: isDark,
                  label: 'Collections',
                  bgColor: isDark ? const Color(0xFF2E221E) : const Color(0xFFFDF0EA),
                  iconWidget: _buildCollectionsIcon(),
                  onTap: () {
                    Haptics.light();
                    onCollectionsTap();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExploreCard({
    required bool isDark,
    required String label,
    required Color bgColor,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 68.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: iconWidget),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersIcon() {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.3,
          child: Icon(
            Icons.local_offer_rounded,
            color: const Color(0xFF2563EB),
            size: 22.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildGourmetIcon() {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.room_service_rounded,
          color: const Color(0xFF7C3AED),
          size: 22.sp,
        ),
      ),
    );
  }

  Widget _buildTop10Icon() {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.workspace_premium_rounded,
          color: const Color(0xFFD97706),
          size: 24.sp,
        ),
      ),
    );
  }

  Widget _buildCollectionsIcon() {
    return Container(
      width: 38.w,
      height: 38.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: const Color(0xFFEA580C),
          size: 22.sp,
        ),
      ),
    );
  }
}
