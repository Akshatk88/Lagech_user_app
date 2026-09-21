import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../../data/models/address_model.dart';
import '../viewmodels/veg_filter_provider.dart';
import '../../search/widgets/voice_search_dialog.dart';
import '../../../../generated/l10n/app_localizations.dart';
import '../viewmodels/banners_viewmodel.dart';
import 'promo_banner_carousel.dart';
import '../../branding/app_colors.dart';

class HomeHeaderBanner extends ConsumerWidget {
  const HomeHeaderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24.r)),
      child: Container(
        width: double.infinity,
        color: AppColors.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 8.h, bottom: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Row
                _buildTopRow(context, ref),

                SizedBox(height: 20.h),

                // Search Bar and Veg Toggle
                _buildSearchBar(context, ref),

                SizedBox(height: 20.h),

                // Promotional Banners Carousel
                ref.watch(promoBannersProvider).when(
                  data: (banners) => banners.isEmpty
                      ? const SizedBox.shrink()
                      : PromoBannerCarousel(banners: banners),
                  loading: () => const SizedBox.shrink(),
                  error: (err, stack) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authViewModelProvider).value;
    final addresses = ref.watch(addressViewModelProvider);
    final defaultAddress = addresses.cast<AddressModel?>().firstWhere(
      (a) => a?.isDefault == true,
      orElse: () => addresses.firstOrNull,
    );

    String locationTitle = 'Home';
    String locationSubtitle = 'Choose your location';

    if (defaultAddress != null) {
      if (defaultAddress.title.isNotEmpty) {
        locationTitle = defaultAddress.title;
      } else if (defaultAddress.type.isNotEmpty) {
        locationTitle = defaultAddress.type;
      }
      
      final parts = [defaultAddress.street, defaultAddress.city].where((s) => s.isNotEmpty).toList();
      locationSubtitle = parts.isNotEmpty ? parts.join(', ') : defaultAddress.fullAddress;
      
      if (locationSubtitle.isEmpty) {
        locationSubtitle = 'Choose your location';
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Location Pin & Address
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              context.push(RouteNames.addAddress);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // White Location Pin Icon
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: const Color(0xFF38019D),
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 8.w),

                // Location Info
                Expanded(
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
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ],
                      ),
                      Text(
                        locationSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.5.sp,
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

        // Wallet Icon
        _buildTopActionIcon(Icons.account_balance_wallet_outlined, () {
          Haptics.light();
          // TODO: Navigate to wallet
        }),
        SizedBox(width: 8.w),

        // Notification Icon
        _buildTopActionIcon(Icons.notifications_outlined, () {
          Haptics.light();
          context.push(RouteNames.notifications);
        }),
        SizedBox(width: 8.w),

        // User Avatar / Initial
        GestureDetector(
          onTap: () {
            Haptics.light();
            context.go(RouteNames.profile);
          },
          child: Container(
            width: 40.w,
            height: 40.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFBE4B9), // Light yellowish color from mockup
            ),
            child: Center(
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: const Color(0xFF38019D),
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.h,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.black87,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    final isVegOnly = ref.watch(vegFilterProvider);
    
    return Row(
      children: [
        // Container 1: Search Bar + Voice Search Mic
        Expanded(
          child: Container(
            height: 50.h,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: Row(
              children: [
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
                          color: const Color(0xFF008A45),
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.searchHint,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13.sp,
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
                Container(
                  width: 1.w,
                  height: 24.h,
                  color: Colors.grey.shade300,
                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                ),
                InkWell(
                  onTap: () async {
                    Haptics.light();
                    final query = await VoiceSearchDialog.show(context);
                    if (query != null && query.trim().isNotEmpty && context.mounted) {
                      context.push(RouteNames.search, extra: query.trim());
                    }
                  },
                  child: Icon(
                    Icons.mic_none_outlined,
                    color: Colors.black87,
                    size: 22.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 16.w),

        // Container 2: VEG Toggle Pill Button
        InkWell(
          onTap: () {
            Haptics.light();
            ref.read(vegFilterProvider.notifier).toggle();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VEG\nMODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36.w,
                height: 20.h,
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  color: isVegOnly
                      ? const Color(0xFFE8F5E9)
                      : Colors.white.withValues(alpha: 0.5),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isVegOnly ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 16.h,
                    height: 16.h,
                    decoration: BoxDecoration(
                      color: isVegOnly ? const Color(0xFF4CAF50) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
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
}
