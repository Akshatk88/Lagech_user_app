import 'dart:developer' as developer;
import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/exit_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';
import '../cart/widgets/floating_view_cart_bar.dart';
import '../navigation/route_names.dart';
import '../search/widgets/voice_search_dialog.dart';
import '../../data/models/restaurant_model.dart';
import '../../data/models/food_model.dart';
import '../../data/models/category_model.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import '../common_widgets/collapsing_header_delegate.dart';
import 'screens/home_filter_screen.dart';
import 'viewmodels/banners_viewmodel.dart';
import '../../../generated/l10n/app_localizations.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'widgets/category_list.dart';
import 'widgets/home_header_banner.dart';
import 'widgets/nearby_restaurants_list.dart';
import 'widgets/popular_brands_list.dart';
import 'widgets/promo_banner_carousel.dart';
import 'widgets/popular_items_list.dart';
import 'widgets/restaurant_card.dart';

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
  String _selectedCategory = 'All';
  // Flips once the sticky header has mostly collapsed, so the status bar
  // icon color can switch from light (over the banner) to dark (over the
  // plain background) — only triggers a rebuild on the threshold crossing,
  // not on every scroll frame.
  bool _headerCollapsed = false;

  // One consistent rhythm for the whole feed instead of a different gap
  // between every pair of sections: a tight gap under each section's own
  // title, and a slightly larger one separating one section from the next.
  double get _headerGap => 8.h;
  double get _sectionGap => 16.h;

  // Sticky header geometry: the search bar + categories row travel together
  // as one fixed-height block from their original (floating-over-the-banner)
  // position up to a pinned spot below the status bar.
  double get _stickyBlockHeight =>
      50.h + 4.h + 84.h; // search + gap + categories
  double get _bannerToBlockOverlap =>
      26.h; // preserves the original floating-overlap look
  double get _collapsedTopPadding =>
      8.h; // breathing room below the status bar once pinned
  double get _shadowRoom =>
      8.h; // clip-safe room for the sticky block's elevation shadow
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
    final homeState = ref.watch(homeViewModelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final topInset = MediaQuery.of(context).padding.top;
    // Matches HomeHeaderBanner's own height calc exactly, so the sticky
    // header's expanded size is pixel-identical to the old static layout.
    final bannerHeight = topInset + 315.h;
    // Expanded: the block floats over the banner exactly as before.
    final expandedBlockTop = bannerHeight - _bannerToBlockOverlap;
    // Collapsed: the block sits pinned just below the status bar.
    final collapsedBlockTop = topInset + _collapsedTopPadding;
    final expandedHeaderExtent =
        expandedBlockTop + _stickyBlockHeight + _shadowRoom;
    final collapsedHeaderExtent =
        collapsedBlockTop + _stickyBlockHeight + _shadowRoom;

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
                          children: [
                            const HomeHeaderBanner(),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: CategoryList(
                                    categories: homeState.categories.asData?.value ?? const [],
                                    selectedCategoryName: _selectedCategory,
                                    onCategorySelected: (catName) {
                                      final categories = homeState.categories.asData?.value ?? [];
                                      final cat = categories.where((c) => c.name.toLowerCase() == catName.toLowerCase()).firstOrNull;
                                      if (cat != null) {
                                        context.push(RouteNames.categoryDetails, extra: cat);
                                      }
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: 16.w, left: 8.w),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    color: const Color(0xFF008A45),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The sticky header already reserves _shadowRoom
                            // worth of clearance below the categories row, so
                            // only the remainder of _sectionGap is needed here
                            // to keep the total spacing identical to before.
                            SizedBox(height: _sectionGap - _shadowRoom),

                            // TEMP DEBUG: shows categories load error, if any.
                            if (homeState.categories.hasError)
                              _DebugErrorBox(
                                label: 'categories',
                                error: homeState.categories.error!,
                              ),

                            // 3. Quick Feature Filter Pills (Trending Now, ₹99 Store, Buy 1 Get 1 Free, Free Delivery, Pure Veg, Near You)
                            _buildQuickFilterPills(isDark),

                            SizedBox(height: _sectionGap),

                            // 4. 99 STORE Section
                            homeState.popularFoods.when(
                              data: (foods) {
                                final isDefaultCategory =
                                    _selectedCategory == 'All' ||
                                    _selectedCategory == 'More';
                                return PopularItemsList(
                                  foods: _filterFoods(
                                    foods,
                                    homeState.categories.asData?.value ??
                                        const [],
                                    ref.watch(vegFilterProvider),
                                  ),
                                  restaurants:
                                      homeState
                                          .nearbyRestaurants
                                          .asData
                                          ?.value ??
                                      const [],
                                  cartBarKey: _cartBarKey,
                                  onAddToCartAnimationComplete: () {
                                    _cartBarKey.currentState?.bump();
                                  },
                                  is99Store: false,
                                  overrideTitle: null,
                                );
                              },
                              loading: () => const SkeletonBanner(height: 140),
                              error: (err, stack) => _DebugErrorBox(
                                label: 'popularFoods',
                                error: err,
                              ),
                            ),

                            SizedBox(height: _sectionGap),

                            // 5. RESTAURANTS NEAR YOU Section
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                );
                                if (restaurants.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.restaurantsNearYou,
                                      onViewAll: () => _openFilter(
                                        title: 'Near You',
                                        emptyMessage:
                                            'No nearby fast-delivery restaurants right now',
                                        emptyIcon: Icons.location_on_rounded,
                                        matches: (r) => r.isNearAndFast,
                                      ),
                                      isDark: isDark,
                                    ),
                                    SizedBox(height: _headerGap),
                                    NearbyRestaurantsList(
                                      restaurants: restaurants,
                                    ),
                                  ],
                                );
                              },
                              loading: () => const SkeletonBanner(height: 180),
                              error: (err, stack) => _DebugErrorBox(
                                label: 'nearbyRestaurants',
                                error: err,
                              ),
                            ),

                            SizedBox(height: _sectionGap),

                            // 5b. Promotional banners moved to the top header.

                            // 6. POPULAR BRANDS Section
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                );
                                if (restaurants.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.popularBrands,
                                      onViewAll: () => _openFilter(
                                        title: 'Popular Brands',
                                        emptyMessage:
                                            'No popular brands found right now',
                                        emptyIcon:
                                            Icons.store_mall_directory_rounded,
                                        matches: (r) => true,
                                      ),
                                      isDark: isDark,
                                    ),
                                    SizedBox(height: _headerGap),
                                    PopularBrandsList(restaurants: restaurants),
                                  ],
                                );
                              },
                              loading: () => const SkeletonBanner(height: 80),
                              error: (err, stack) => _DebugErrorBox(
                                label: 'popularBrands',
                                error: err,
                              ),
                            ),

                            SizedBox(height: _sectionGap),

                            // 8. RESTAURANTS DELIVERING TO YOU Vertical List Section
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                );
                                if (restaurants.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final totalCount = restaurants.length;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.restaurantsDeliveringToYou(totalCount),
                                      onViewAll: null,
                                      isDark: isDark,
                                    ),
                                    SizedBox(height: _headerGap),
                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                              loading: () =>
                                  const SkeletonRestaurantList(count: 3),
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


  /// 4. Quick Feature Filter Pills Row
  Widget _buildQuickFilterPills(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final pills = [
      {
        'icon': Icons.local_fire_department_rounded,
        'title': l10n.pillTrending,
        'highlight': l10n.pillNow,
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Trending Now',
          emptyMessage: 'No trending restaurants right now',
          emptyIcon: Icons.local_fire_department_rounded,
          matches: (r) => r.isFeatured,
        ),
      },
      {
        'icon': Icons.currency_rupee_rounded,
        'title': '99',
        'highlight': l10n.pillStore,
        'bg': const Color(0xFFFFF9E6),
        'color': const Color(0xFFF57F17),
        'onTap': () {
          Haptics.light();
          context.push(RouteNames.store99);
        },
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'title': l10n.pillBuy1Get1,
        'highlight': l10n.pillFree,
        'bg': AppColors.success.withValues(alpha: 0.12),
        'color': AppColors.success,
        'onTap': () => _openFilter(
          title: 'Buy 1 Get 1 Free',
          emptyMessage: 'No Buy 1 Get 1 Free meals available right now',
          emptyIcon: Icons.card_giftcard_rounded,
          matches: (r) => r.offerBadges.any(
            (b) => RegExp(
              r'buy\s*1|b\s*1\s*g\s*1',
              caseSensitive: false,
            ).hasMatch(b),
          ),
        ),
      },
      {
        'icon': Icons.directions_bike_rounded,
        'title': l10n.pillFreeCaps,
        'highlight': l10n.pillDelivery,
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Free Delivery',
          emptyMessage: 'No free-delivery restaurants nearby right now',
          emptyIcon: Icons.delivery_dining_rounded,
          matches: (r) => r.deliveryFee <= 0,
        ),
      },
      {
        'icon': Icons.eco_rounded,
        'title': l10n.pillPureVeg,
        'highlight': '',
        'bg': AppColors.success.withValues(alpha: 0.12),
        'color': AppColors.success,
        // No per-restaurant veg flag exists on the backend yet — this filters
        // the real food list below (same switch as the VEG toggle) rather
        // than fabricating one.
        'onTap': () {
          Haptics.light();
          ref.read(vegFilterProvider.notifier).set(true);
        },
      },
      {
        'icon': Icons.location_on_outlined,
        'title': l10n.pillNearYou,
        'highlight': '',
        'bg': const Color(0xFFF8F0FF),
        'color': const Color(0xFF7B1FA2),
        'onTap': () => _openFilter(
          title: 'Near You',
          emptyMessage: 'No nearby fast-delivery restaurants right now',
          emptyIcon: Icons.location_on_rounded,
          matches: (r) => r.isNearAndFast,
        ),
      },
    ];

    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: pills.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final p = pills[index];
          final bgColor = isDark ? AppColors.surfaceDark : (p['bg'] as Color);
          final textColor = p['color'] as Color;

          return InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: p['onTap'] as VoidCallback,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, color: textColor, size: 15.sp),
                  SizedBox(width: 5.w),
                  Text(
                    p['title'] as String,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  if ((p['highlight'] as String).isNotEmpty) ...[
                    SizedBox(width: 3.w),
                    Text(
                      p['highlight'] as String,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
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

  /// Section Header (Title + LAGECH Primary View All >)
  Widget _buildSectionHeader({
    required String title,
    required VoidCallback? onViewAll,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          if (onViewAll != null)
            InkWell(
              onTap: () {
                Haptics.light();
                onViewAll();
              },
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.viewAll,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16.sp,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<FoodModel> _filterFoods(
    List<FoodModel> foods,
    List<CategoryModel> categories,
    bool isVegOnly,
  ) {
    var result = foods;
    if (isVegOnly) {
      result = result.where((f) => f.isVeg).toList();
    }
    return result;
  }

  List<RestaurantModel> _filterRestaurants(List<RestaurantModel> restaurants) {
    final isVegOnly = ref.watch(vegFilterProvider);
    var list = restaurants;
    if (isVegOnly) {
      list = list.where((r) => r.isPureVeg).toList();
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
}
