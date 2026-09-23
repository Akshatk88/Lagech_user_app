import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/exit_confirmation_dialog.dart';
import '../common_widgets/smart_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';
import '../cart/widgets/floating_view_cart_bar.dart';
import '../navigation/route_names.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/category_model.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import 'screens/home_filter_screen.dart';
import 'viewmodels/banners_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/home_scroll_provider.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'widgets/category_list.dart';
import 'widgets/home_header_banner.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/explore_more_section.dart';
import 'widgets/home_filter_chips_row.dart';

/// TEMP DEBUG WIDGET — shows the exact error inline instead of a blank
/// SizedBox.shrink(). Remove once the root cause of missing data is fixed.
class _DebugErrorBox extends StatelessWidget {
  final String label;
  final Object error;

  const _DebugErrorBox({required this.label, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Text(
        '[$label] $error',
        style: const TextStyle(color: Colors.red, fontSize: 11),
      ),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final ScrollController _scrollController = ScrollController();
  final String _selectedCategory = 'All';
  String? _activeFilter;
  // Flips once the sticky header has mostly collapsed, so the status bar
  // icon color can switch from light (over the banner) to dark (over the
  // plain background) — only triggers a rebuild on the threshold crossing,
  // not on every scroll frame.
  bool _headerCollapsed = false;

  // One consistent rhythm for the whole feed instead of a different gap
  // between every pair of sections: a tight gap under each section's own
  // title, and a slightly larger one separating one section from the next.


  double get _bannerToBlockOverlap =>
      26.h; // preserves the original floating-overlap look
  double get _collapsedTopPadding =>
      8.h; // breathing room below the status bar once pinned
  double get _headerRange =>
      315.h - _bannerToBlockOverlap - _collapsedTopPadding;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final collapsed = _scrollController.offset > _headerRange * 0.7;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeScrollToTopProvider, (_, _) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final homeState = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (_headerCollapsed && !isDark)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: () async {
                    String? activeCategorySlug;
                    if (_selectedCategory != 'All' &&
                        _selectedCategory != 'More') {
                      final categories =
                          homeState.categories.asData?.value ?? [];
                      final cat = categories
                          .where((c) => c.name == _selectedCategory)
                          .firstOrNull;
                      activeCategorySlug = cat?.slug;
                    }

                    await ref
                        .read(homeViewModelProvider.notifier)
                        .loadHomeData(
                          isRefresh: true,
                          categoryId: activeCategorySlug,
                        );
                    await ref
                        .read(activeOrderViewModelProvider.notifier)
                        .fetchActiveOrder(isRefresh: true);
                    // Banners are their own provider, so loadHomeData does not
                    // touch them — without this a banner the admin just published
                    // would not appear until the app was restarted.
                    ref.invalidate(promoBannersProvider);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Top Header Banner (Lavender wash, Appzeto, Location, Search+Veg, Special Offer Banner)
                            const HomeHeaderBanner(),

                            SizedBox(height: 12.h),

                            // 2. Categories Row with Leading "MEALS UNDER ₹200" badge
                            CategoryList(
                              categories: homeState.categories.asData?.value ?? const [],
                              selectedCategoryName: _selectedCategory,
                              onMealsUnder200Tap: () {
                                Haptics.light();
                                context.push(RouteNames.store99);
                              },
                              onCategorySelected: (catName) {
                                final categories = homeState.categories.asData?.value ?? [];
                                final cat = categories
                                    .where((c) => c.name.toLowerCase() == catName.toLowerCase())
                                    .firstOrNull;
                                if (cat != null) {
                                  context.push(
                                    RouteNames.categoryDetails,
                                    extra: cat,
                                  );
                                }
                              },
                            ),

                            SizedBox(height: 14.h),

                            // 3. Filter Chips Row: Filters, Under 30 mins, Under 45 mins, Under 1km
                            HomeFilterChipsRow(
                              activeFilter: _activeFilter,
                              onFiltersTap: () {
                                _showCategoryFilterSheet(
                                  context,
                                  isDark,
                                  homeState.categories.asData?.value ?? const [],
                                );
                              },
                              onUnder30MinsTap: () {
                                setState(() {
                                  _activeFilter = (_activeFilter == '30mins') ? null : '30mins';
                                });
                              },
                              onUnder45MinsTap: () {
                                setState(() {
                                  _activeFilter = (_activeFilter == '45mins') ? null : '45mins';
                                });
                              },
                              onUnder1KmTap: () {
                                setState(() {
                                  _activeFilter = (_activeFilter == '1km') ? null : '1km';
                                });
                              },
                            ),

                            SizedBox(height: 16.h),

                            // 4. EXPLORE MORE Section: Offers, Gourmet, Top 10, Collections
                            ExploreMoreSection(
                              onOffersTap: () => context.push(RouteNames.allOffers),
                              onGourmetTap: () => _openFilter(
                                title: 'Gourmet',
                                emptyMessage: 'No gourmet restaurants found right now',
                                emptyIcon: Icons.room_service_rounded,
                                matches: (r) => r.rating >= 4.2,
                              ),
                              onTop10Tap: () => _openFilter(
                                title: 'Top 10',
                                emptyMessage: 'No top rated restaurants found',
                                emptyIcon: Icons.workspace_premium_rounded,
                                matches: (r) => r.rating >= 4.0,
                              ),
                              onCollectionsTap: () => context.push(RouteNames.store99),
                            ),

                            SizedBox(height: 20.h),

                            // 5. Featured Restaurants Section (Matching Screenshot)
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(allRestaurants);
                                if (restaurants.isEmpty) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                                    child: Center(
                                      child: Text(
                                        'No restaurants available matching criteria',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Subtitle & Title matching screenshot:
                                    // "13 RESTAURANTS DELIVERING TO YOU"
                                    // "Featured"
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${restaurants.length} RESTAURANTS DELIVERING TO YOU',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.9,
                                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            'Featured',
                                            style: TextStyle(
                                              fontSize: 22.sp,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(height: 12.h),

                                    // Restaurant Cards
                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: restaurants.length,
                                      itemBuilder: (context, index) {
                                        return RestaurantCard(
                                          restaurant: restaurants[index],
                                          index: index,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SkeletonRestaurantList(count: 3),
                              error: (err, stack) => _DebugErrorBox(
                                label: 'restaurantsList',
                                error: err,
                              ),
                            ),

                            SizedBox(height: 100.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating View Cart Bar
                FloatingViewCartBar(
                  key: _cartBarKey,
                  onTap: () {
                    Haptics.light();
                    context.go(RouteNames.cart);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _openFilter({
    required String title,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool Function(RestaurantModel) matches,
  }) {
    Haptics.light();
    context.push(
      RouteNames.homeFilter,
      extra: HomeFilterArgs(
        title: title,
        emptyMessage: emptyMessage,
        emptyIcon: emptyIcon,
        matches: matches,
      ),
    );
  }



  List<RestaurantModel> _filterRestaurants(List<RestaurantModel> restaurants) {
    final isVegOnly = ref.watch(vegFilterProvider);
    var list = restaurants;
    if (isVegOnly) {
      list = list.where((r) => r.isPureVeg).toList();
    }
    if (_activeFilter == '30mins') {
      list = list.where((r) => r.deliveryTime.contains('30') || r.deliveryTime.contains('20') || r.deliveryTime.contains('15') || r.deliveryTime.contains('25')).toList();
    } else if (_activeFilter == '45mins') {
      list = list.where((r) => r.deliveryTime.contains('45') || r.deliveryTime.contains('30') || r.deliveryTime.contains('25') || r.deliveryTime.contains('35') || r.deliveryTime.contains('40')).toList();
    } else if (_activeFilter == '1km') {
      list = list.where((r) => r.distanceKm <= 1.5).toList();
    }
    if (_selectedCategory == 'All' || _selectedCategory == 'More') {
      return list;
    }
    final query = _selectedCategory.toLowerCase().trim();
    final singular = query.endsWith('s')
        ? query.substring(0, query.length - 1)
        : query;
    return list.where((r) {
      final haystack =
          '${r.name} ${r.tags.join(' ')} ${r.restaurantTags.join(' ')}'
              .toLowerCase();
      return haystack.contains(query) || haystack.contains(singular);
    }).toList();
  }

  void _showCategoryFilterSheet(
    BuildContext context,
    bool isDark,
    List<CategoryModel> categories,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: 0.85.sh),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Cuisines',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  children: [
                    if (categories.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Text(
                          'No cuisines found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10.w,
                          mainAxisSpacing: 20.h,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          return InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push(
                                RouteNames.categoryDetails,
                                extra: cat,
                              );
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60.r,
                                  height: 60.r,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: SmartImage(
                                      url: cat.imageUrl,
                                      category: ImageCategory.category,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  cat.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    SizedBox(height: 20.h),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
