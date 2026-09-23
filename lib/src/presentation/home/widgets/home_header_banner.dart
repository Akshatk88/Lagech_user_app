import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../../data/models/address_model.dart';
import '../viewmodels/veg_filter_provider.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../search/widgets/voice_search_dialog.dart';
import '../../navigation/route_names.dart';
import '../../branding/app_colors.dart';

class HomeHeaderBanner extends ConsumerWidget {
  const HomeHeaderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.surfaceDark,
                  AppColors.backgroundDark,
                ]
              : [
                  const Color(0xFFEADBFA), // Soft Lilac / Lavender
                  const Color(0xFFF6F0FB),
                  Colors.white,
                ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: [
                  // 1. Top Row: Location, Appzeto Logo, Wallet & Cart
                  _buildTopRow(context, ref, isDark),

                  SizedBox(height: 14.h),

                  // 2. Search Bar and VEG Mode Toggle
                  _buildSearchBarAndVegMode(context, ref, isDark),
                ],
              ),
            ),

            // 3. Special Offer Express Delivery Banner
            _buildSpecialOfferBanner(context, isDark),

            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, WidgetRef ref, bool isDark) {
    final addresses = ref.watch(addressViewModelProvider);
    final defaultAddress = addresses.cast<AddressModel?>().firstWhere(
      (a) => a?.isDefault == true,
      orElse: () => addresses.firstOrNull,
    );
    final cartItemCount = ref.watch(cartViewModelProvider).items.length;

    String locationTitle = 'Indore';
    String locationSubtitle = 'Madhya Pradesh';

    if (defaultAddress != null) {
      if (defaultAddress.title.isNotEmpty) {
        locationTitle = defaultAddress.title;
      } else if (defaultAddress.city.isNotEmpty) {
        locationTitle = defaultAddress.city;
      }

      final parts = [defaultAddress.street, defaultAddress.city]
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        locationSubtitle = parts.join(', ');
      } else if (defaultAddress.fullAddress.isNotEmpty) {
        locationSubtitle = defaultAddress.fullAddress;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Location with Pin and Dropdown
        Expanded(
          flex: 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              context.push(RouteNames.addAddress);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  size: 19.sp,
                ),
                SizedBox(width: 4.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              locationTitle,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF111827),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                            size: 18.sp,
                          ),
                        ],
                      ),
                      Text(
                        locationSubtitle,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Center: Appzeto Logo
        Expanded(
          flex: 4,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Appzeto',
                  style: TextStyle(
                    color: const Color(0xFF00A896), // Brand Teal / Cyan
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  width: 5.r,
                  height: 5.r,
                  margin: EdgeInsets.only(left: 2.w, top: 8.h),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B), // Warm yellow dot
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: Wallet & Cart Buttons
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Wallet Button
              _buildTopActionButton(
                icon: Icons.account_balance_wallet_outlined,
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.wallet);
                },
                isDark: isDark,
              ),
              SizedBox(width: 8.w),

              // Cart Button
              _buildTopActionButton(
                icon: Icons.shopping_bag_outlined,
                badgeCount: cartItemCount,
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.cart);
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF374151),
              size: 19.sp,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFE50914),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBarAndVegMode(BuildContext context, WidgetRef ref, bool isDark) {
    final isVegOnly = ref.watch(vegFilterProvider);

    return Row(
      children: [
        // Left: Rounded White Capsule Search Bar
        Expanded(
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Search Icon
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Haptics.light();
                      context.push(RouteNames.search);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: const Color(0xFF00A896),
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Search "biryani"',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mic Icon
                InkWell(
                  onTap: () async {
                    Haptics.light();
                    final query = await VoiceSearchDialog.show(context);
                    if (query != null && query.trim().isNotEmpty && context.mounted) {
                      context.push(RouteNames.search, extra: query.trim());
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 6.w),
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      size: 22.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(width: 12.w),

        // Right: VEG MODE Toggle Pill Button
        InkWell(
          onTap: () {
            Haptics.light();
            ref.read(vegFilterProvider.notifier).toggle();
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VEG\nMODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 3.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36.w,
                height: 18.h,
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: isVegOnly
                      ? const Color(0xFF22C55E) // Bright Green
                      : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isVegOnly ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 14.h,
                    height: 14.h,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialOfferBanner(BuildContext context, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF3B1E54),
                  const Color(0xFF2B124C),
                ]
              : [
                  const Color(0xFFE4D0F3), // Pastel Lilac / Violet
                  const Color(0xFFD5BAED),
                  const Color(0xFFC7A2E5),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Column: Text & CTA
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pop Badge: Special Offer!
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(
                      color: const Color(0xFF7E22CE),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Special Offer!',
                    style: TextStyle(
                      color: const Color(0xFF581C87),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 5.h),

                // Subtitle
                Text(
                  '& Get Express Delivery',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF2E1065),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'with every order',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF3B0764),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'on your first order under 7 km',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF581C87),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 10.h),

                // CTA Button: Know more >
                InkWell(
                  onTap: () {
                    Haptics.light();
                    context.push(RouteNames.allOffers);
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B21A8), // Deep Royal Purple
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Know more',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 10.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Right Column: Delivery Boy Illustration
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 110.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pop speed rays / circle background
                  Container(
                    width: 90.r,
                    height: 90.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  // Delivery Bag Artwork
                  Positioned(
                    right: 4.w,
                    child: Container(
                      width: 78.w,
                      height: 82.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9D5FF),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delivery_dining_rounded,
                            size: 40.sp,
                            color: const Color(0xFF7E22CE),
                          ),
                          SizedBox(height: 2.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7E22CE),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'EXPRESS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
