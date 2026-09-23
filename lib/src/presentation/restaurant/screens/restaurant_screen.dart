import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/service/deep_link_service.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/order_providers.dart';
import '../../../domain/model/restaurant_menu_category.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../common_widgets/smart_image.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../orders/utils/reorder.dart';
import '../../search/widgets/voice_search_dialog.dart';
import '../viewmodels/restaurant_state.dart';
import '../viewmodels/restaurant_viewmodel.dart';
import '../widgets/food_detail_sheet.dart';
import 'package:geolocator/geolocator.dart';
import '../../../di/location_providers.dart';

class RestaurantScreen extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;

  const RestaurantScreen({super.key, this.restaurant});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  static const Color _priceGreen = Color(0xFF1FA855);

  late final TextEditingController _searchController;
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final Map<String, GlobalKey> _dishImageKeys = {};

  // ---- Category jump-navigation (chip bar <-> menu sections) ----
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();
  final GlobalKey _topAnchorKey = GlobalKey();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};
  String _activeCategoryId = 'all';
  bool _isAutoScrolling = false;
  List<String> _lastSectionOrder = [];

  // ---- Collapsed categories ----
  final Set<String> _collapsedCategories = {};

  double get _categoryBarHeight => 38.h;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController.addListener(_onMainScroll);

    Future.microtask(() {
      Haptics.light();
      final targetRestaurant = widget.restaurant;
      if (targetRestaurant == null) return;
      ref.read(restaurantViewModelProvider.notifier).loadMenu(targetRestaurant);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  // ==================== CATEGORY JUMP NAVIGATION ====================

  void _onCategoryChipTap(String categoryId) {
    Haptics.light();
    setState(() => _activeCategoryId = categoryId);

    final targetKey = categoryId == 'all'
        ? _topAnchorKey
        : _sectionKeys[categoryId];
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      _isAutoScrolling = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0,
      ).then((_) {
        if (mounted) _isAutoScrolling = false;
      });
    }
    _ensureChipVisible(categoryId);
  }

  void _ensureChipVisible(String categoryId) {
    final chipContext = _chipKeys[categoryId]?.currentContext;
    if (chipContext == null) return;

    // Scope to the horizontal chip Scrollable only. The unscoped
    // Scrollable.ensureVisible() walks every ancestor Scrollable, which
    // would also drag the outer vertical CustomScrollView back toward
    // this pinned header's unpinned position.
    final horizontalScrollable = Scrollable.maybeOf(
      chipContext,
      axis: Axis.horizontal,
    );
    final renderObject = chipContext.findRenderObject();
    if (horizontalScrollable == null || renderObject == null) return;

    horizontalScrollable.position.ensureVisible(
      renderObject,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  void _onMainScroll() {
    if (_isAutoScrolling || !mounted || _lastSectionOrder.isEmpty) return;

    final topThreshold =
        MediaQuery.of(context).padding.top + 58.h + _categoryBarHeight + 4.h;
    String newActive = 'all';
    for (final id in _lastSectionOrder) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= topThreshold) {
        newActive = id;
      } else {
        break;
      }
    }

    if (newActive != _activeCategoryId) {
      setState(() => _activeCategoryId = newActive);
      _ensureChipVisible(newActive);
    }
  }

  int _getQuantity(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.quantity;
    }
    return 0;
  }

  String? _getCartItemId(CartState cartState, String foodId) {
    for (final item in cartState.items) {
      if (item.food.id == foodId) return item.id;
    }
    return null;
  }

  /// Distance to [r] in km, or null when it genuinely cannot be worked out.
  ///
  /// Prefers what the backend measured. Falls back to computing it here from
  /// the restaurant's own coordinates, because distanceKm is only populated
  /// when *that particular request* carried the user's lat/lng — open the same
  /// restaurant from search or a shared link and it arrives as 0 even though
  /// both sets of coordinates are on hand.
  double? _resolvedDistanceKm(RestaurantModel r) {
    if (r.distanceKm > 0) return r.distanceKm;

    final rLat = r.latitude;
    final rLng = r.longitude;
    final me = ref.watch(userLatLngProvider).value;
    if (rLat == null || rLng == null || me == null) return null;

    final km = Geolocator.distanceBetween(me.lat, me.lng, rLat, rLng) / 1000;
    return km > 0 ? km : null;
  }

  @override
  Widget build(BuildContext context) {
    final restaurantState = ref.watch(restaurantViewModelProvider);
    final cartState = ref.watch(cartViewModelProvider);
    final currentRestaurant = restaurantState.restaurant ?? widget.restaurant;

    // Reached only via a restaurant card, so this is defensive rather than a
    // real state — but it must not fabricate a placeholder restaurant.
    if (currentRestaurant == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Restaurant unavailable')),
      );
    }

    final isFavorite = ref.watch(
      favoritesViewModelProvider.select(
        (s) => s.value?.restaurantIds.contains(currentRestaurant.id) ?? false,
      ),
    );

    final groupedByCategory = restaurantState.isLoading
        ? const <String, List<FoodModel>>{}
        : ref
              .read(restaurantViewModelProvider.notifier)
              .groupFilteredByCategory();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  // FIXED RESTAURANT HEADER (outside RefreshIndicator & ScrollView)
                  _buildTopSection(
                    context,
                    currentRestaurant,
                    isFavorite,
                  ),

                  // REFRESHABLE MENU CONTENT AREA
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        Haptics.light();
                        await ref
                            .read(restaurantViewModelProvider.notifier)
                            .loadMenu(currentRestaurant, isRefresh: true);
                      },
                      color: AppColors.primary,
                      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Sticky Search Bar + Filter Chips
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _StickySearchBarDelegate(
                              child: _buildSearchBar(
                                context,
                                currentRestaurant,
                                restaurantState,
                              ),
                              topPadding: 0,
                            ),
                          ),

                          // Sticky Category Chip Bar
                          if (restaurantState.categories.length > 1)
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickyCategoryBarDelegate(
                                child: _buildCategoryChipsBar(context, restaurantState),
                                barHeight: _categoryBarHeight,
                              ),
                            ),

                          // Main Content Body
                          SliverToBoxAdapter(
                            child: restaurantState.isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                        SkeletonFoodItemCard(),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      SizedBox(height: 4.h),
                                      if (currentRestaurant.id.isNotEmpty)
                                        _buildPreviousOrdersSection(context, currentRestaurant.id),
                                      // Dishes grouped into jump-to category sections
                                      _buildCategorySections(
                                        context,
                                        restaurantState.categories,
                                        groupedByCategory,
                                        cartState,
                                      ),
                                      SizedBox(height: 110.h),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Floating View Cart Bar
              FloatingViewCartBar(
                key: _cartBarKey,
                onTap: () {
                  Haptics.light();
                  context.go(RouteNames.cart);
                },
              ),

              // Floating MENU Button
              Positioned(
                right: 20.w,
                bottom: cartState.items.isNotEmpty ? 90.h : 20.h,
                child: _buildFloatingMenuButton(context, restaurantState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== TOP HEADER SECTION (HERO IMAGE) ====================

  Widget _buildTopSection(
    BuildContext context,
    RestaurantModel restaurant,
    bool isFavorite,
  ) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final heroHeight = 230.h + statusBarHeight;

    // Pick best image: coverImages first, then imageUrl
    final heroImageUrl = restaurant.coverImages.isNotEmpty
        ? restaurant.coverImages.first
        : restaurant.imageUrl;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ---- Hero Image ----
          heroImageUrl.isNotEmpty
              ? SmartImage(
                  url: heroImageUrl,
                  category: ImageCategory.restaurant,
                  fit: BoxFit.cover,
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),

          // ---- Gradient Overlay (bottom) ----
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),

          // ---- Content ----
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, statusBarHeight + 8.h, 16.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Back + Share + Fav
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(RouteNames.home);
                        }
                      },
                      child: Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),
                    // Share + Fav buttons
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Haptics.light();
                            final text = DeepLinkService.generateRestaurantShareText(
                              restaurantName: restaurant.name,
                              restaurantId: restaurant.id,
                              cuisines: restaurant.tags.join(', '),
                            );
                            SharePlus.instance.share(ShareParams(text: text));
                          },
                          child: Container(
                            width: 36.r,
                            height: 36.r,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ---- Restaurant Info (bottom of hero) ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Name + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            restaurant.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          // Delivery time · distance · area
                          Text(
                            [
                              if (restaurant.deliveryTime.isNotEmpty) restaurant.deliveryTime,
                              if (_resolvedDistanceKm(restaurant) case final km?)
                                '${km.toStringAsFixed(1)} km',
                              if (restaurant.area.isNotEmpty) restaurant.area,
                            ].join('  ·  '),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (restaurant.priceForOne > 0) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Min order ₹${restaurant.priceForOne.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          SizedBox(height: 8.h),
                          // Chips row: Pure Veg / Free Delivery / Offer badges
                          Wrap(
                            spacing: 6.w,
                            runSpacing: 4.h,
                            children: [
                              if (restaurant.isPureVeg)
                                _buildHeroBadgeChip('Pure Veg', const Color(0xFF008A45)),
                              if (restaurant.isFreeDelivery)
                                _buildHeroBadgeChip('Free Delivery', AppColors.primary),
                              if (restaurant.isFeatured)
                                _buildHeroBadgeChip('Featured', AppColors.primary),
                            ],
                          ),
                          SizedBox(height: 12.h),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Right side: Rating badge + Fav button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Favorite button
                        GestureDetector(
                          onTap: () {
                            Haptics.medium();
                            ref
                                .read(favoritesViewModelProvider.notifier)
                                .toggle(restaurant.id, restaurant);
                          },
                          child: Container(
                            width: 36.r,
                            height: 36.r,
                            margin: EdgeInsets.only(bottom: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite
                                  ? const Color(0xFFFF4B72)
                                  : Colors.white,
                              size: 18.sp,
                            ),
                          ),
                        ),
                        // Rating badge
                        Builder(
                          builder: (context) {
                            final displayRating = restaurant.rating > 0
                                ? restaurant.rating.toStringAsFixed(1)
                                : '4.5';
                            return Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF008A45),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 13.sp,
                                      ),
                                      SizedBox(width: 3.w),
                                      Text(
                                        displayRating,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (restaurant.reviewCount > 0) ...[
                                  SizedBox(height: 3.h),
                                  Text(
                                    'By ${restaurant.reviewCount}+',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        SizedBox(height: 12.h),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ---- Closed overlay ----
          if (!restaurant.isOpen)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                color: Colors.black.withValues(alpha: 0.55),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: Colors.white70, size: 14.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'Delivery currently unavailable',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
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

  Widget _buildHeroBadgeChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: label == 'Pure Veg' ? const Color(0xFF55E47B) : Colors.white,
        ),
      ),
    );
  }

  // ==================== PREMIUM STICKY SEARCH BAR ====================

  Widget _buildSearchBar(
    BuildContext context,
    RestaurantModel restaurant,
    RestaurantState state,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = ref.read(restaurantViewModelProvider.notifier);

    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Search Bar ----
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 4.h),
            child: Container(
              height: 38.h,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[500],
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      onChanged: (val) {
                        vm.setSearchQuery(val);
                      },
                      onTap: () {
                        Haptics.light();
                      },
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search in ${restaurant.name}',
                        hintStyle: TextStyle(
                          fontSize: 12.5.sp,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (state.searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        _searchController.clear();
                        vm.setSearchQuery('');
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : Colors.grey[500],
                          size: 16.sp,
                        ),
                      ),
                    ),
                  SizedBox(width: 4.w),
                  // Mic button
                  GestureDetector(
                    onTap: () async {
                      Haptics.light();
                      final query = await VoiceSearchDialog.show(context);
                      if (query != null && query.trim().isNotEmpty && context.mounted) {
                        developer.log('[VOICE] Search query passed: "$query"', name: 'VOICE');
                        _searchController.text = query.trim();
                        vm.setSearchQuery(query.trim());
                      }
                    },
                    child: Icon(
                      Icons.mic_outlined,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[500],
                      size: 18.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Filter Chips Row ----
          _buildFilterChipsRow(context, state),

          // ---- Divider ----
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.borderDark : Colors.grey.shade100,
          ),
        ],
      ),
    );
  }

  // ==================== FILTER CHIPS ROW ====================

  Widget _buildFilterChipsRow(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = ref.read(restaurantViewModelProvider.notifier);

    return SizedBox(
      height: 32.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: [
          // Non-Veg toggle chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (state.isVegOnly) vm.toggleVegOnly();
              vm.toggleNonVegOnly();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: state.isNonVegOnly
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isNonVegOnly
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Non-veg toggle track
                  Container(
                    width: 24.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: state.isNonVegOnly
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(7.r),
                      border: Border.all(
                        color: state.isNonVegOnly
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: state.isNonVegOnly
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(1.5.r),
                        child: Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: state.isNonVegOnly
                                ? AppColors.primary
                                : Colors.grey.shade500,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Non-Veg',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isNonVegOnly
                          ? AppColors.primary
                          : (isDark ? AppColors.textSecondaryDark : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Veg toggle chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (state.isNonVegOnly) vm.toggleNonVegOnly();
              vm.toggleVegOnly();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: state.isVegOnly
                    ? const Color(0xFF008A45).withValues(alpha: 0.10)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isVegOnly
                      ? const Color(0xFF008A45)
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildVegIcon(size: 10),
                  SizedBox(width: 4.w),
                  Text(
                    'Veg',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isVegOnly
                          ? const Color(0xFF008A45)
                          : (isDark ? AppColors.textSecondaryDark : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Best Seller toggle chip
          GestureDetector(
            onTap: () {
              Haptics.light();
              vm.toggleBestSeller();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: state.isBestSellerOnly
                    ? const Color(0xFFFF5200).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isBestSellerOnly
                      ? const Color(0xFFFF5200)
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 14.sp,
                    color: state.isBestSellerOnly
                        ? const Color(0xFFFF5200)
                        : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Best seller',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isBestSellerOnly
                          ? const Color(0xFFFF5200)
                          : (isDark ? AppColors.textSecondaryDark : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Rating sort toggle chip (shows highest rating food first)
          GestureDetector(
            onTap: () {
              Haptics.light();
              vm.toggleRatingSort();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              decoration: BoxDecoration(
                color: state.isRatingSort
                    ? const Color(0xFF008A45).withValues(alpha: 0.12)
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: state.isRatingSort
                      ? const Color(0xFF008A45)
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rate_rounded,
                    size: 14.sp,
                    color: state.isRatingSort
                        ? const Color(0xFF008A45)
                        : (isDark ? AppColors.textSecondaryDark : Colors.grey[600]),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Rating',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: state.isRatingSort
                          ? const Color(0xFF008A45)
                          : (isDark ? AppColors.textSecondaryDark : Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 4.w),
        ],
      ),
    );
  }

  // ==================== ORDER AGAIN (PREVIOUS ORDERS) ====================

  Future<void> _handleReorderFromDetail(OrderModel order) async {
    final allowed = await ensureCartRestaurant(context, ref, order.restaurantId);
    if (!allowed || !context.mounted) return;

    Haptics.medium();
    final items = await resolveReorderItems(ref, order);
    if (!context.mounted) return;
    final cartNotifier = ref.read(cartViewModelProvider.notifier);
    for (final item in items) {
      cartNotifier.addItem(
        item.food,
        quantity: item.quantity,
        selectedVariant: item.selectedVariant,
        selectedVariantPrice: item.selectedVariantPrice,
        selectedAddons: item.selectedAddons,
        selectedAddonsPrice: item.selectedAddonsPrice,
      );
    }
    if (mounted) context.go(RouteNames.cart);
  }

  Widget _buildPreviousOrdersSection(BuildContext context, String restaurantId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pastOrdersAsync = ref.watch(restaurantPastOrdersProvider(restaurantId));

    return pastOrdersAsync.when(
      data: (orders) {
        if (orders.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Order again',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                height: 112.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => SizedBox(width: 10.w),
                  itemBuilder: (context, i) {
                    final order = orders[i];
                    final itemCount = order.items.fold<int>(0, (sum, it) => sum + it.quantity);
                    final dateLabel = order.createdAt != null
                        ? DateFormat('d MMM').format(order.createdAt!.toLocal())
                        : '';
                    return Container(
                      width: 168.w,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemCount == 1 ? '1 item' : '$itemCount items',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            [
                              if (dateLabel.isNotEmpty) dateLabel,
                              '₹${order.total.toStringAsFixed(0)}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 30.h,
                            child: OutlinedButton(
                              onPressed: () => _handleReorderFromDetail(order),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              child: Text(
                                'Reorder',
                                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  // ==================== CATEGORY CHIP BAR (jump navigation) ====================

  Widget _buildCategoryChipsBar(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seenIds = <String>{};
    final seenNames = <String>{};
    final categories = <RestaurantMenuCategory>[];

    for (final cat in state.categories) {
      final idKey = cat.id.trim();
      final nameKey = cat.name.trim().toLowerCase();

      if (idKey.isNotEmpty && seenIds.contains(idKey)) continue;
      if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;

      if (idKey.isNotEmpty) seenIds.add(idKey);
      if (nameKey.isNotEmpty) seenNames.add(nameKey);
      categories.add(cat);
    }

    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 32.h,
      child: ListView.separated(
        controller: _chipScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = _activeCategoryId == category.id;
          final chipKey = _chipKeys.putIfAbsent(category.id, () => GlobalKey());

          return GestureDetector(
            key: chipKey,
            onTap: () => _onCategoryChipTap(category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : Colors.grey.shade300),
                  width: 1,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : Colors.grey[700]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }



  // ==================== CATEGORY SECTIONS (jump-to-section menu) ====================

  Widget _buildCategorySections(
    BuildContext context,
    List<RestaurantMenuCategory> categories,
    Map<String, List<FoodModel>> grouped,
    CartState cartState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = categories
        .where((c) => c.id != 'all' && (grouped[c.id]?.isNotEmpty ?? false))
        .toList();

    _lastSectionOrder = sections.map((c) => c.id).toList();

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            'No dishes match your filters.',
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Column(
      key: _topAnchorKey,
      children: [
        for (final category in sections) ...[
          // ---- Category Header (tappable collapse/expand) ----
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() {
                if (_collapsedCategories.contains(category.id)) {
                  _collapsedCategories.remove(category.id);
                } else {
                  _collapsedCategories.add(category.id);
                }
              });
            },
            child: Container(
              key: _sectionKeys.putIfAbsent(category.id, () => GlobalKey()),
              color: Colors.transparent,
              padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                  Text(
                    '(${grouped[category.id]!.length})',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  AnimatedRotation(
                    turns: _collapsedCategories.contains(category.id) ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 22.sp,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- Category Items (collapsible) ----
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: _collapsedCategories.contains(category.id)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildDishesGrid(context, grouped[category.id]!, cartState),
            secondChild: const SizedBox.shrink(),
          ),

          // ---- Divider between categories ----
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : Colors.grey.shade200,
            ),
          ),
        ],
        SizedBox(height: 8.h),
      ],
    );
  }

  // ==================== DISHES GRID WITH FOOD CARD NAVIGATION ====================

  Widget _buildDishesGrid(
    BuildContext context,
    List<FoodModel> dishes,
    CartState cartState,
  ) {
    if (dishes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            'No dishes match your filters.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: dishes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 24.h,
          childAspectRatio: 0.58,
        ),
        itemBuilder: (context, index) {
          return _buildGridDishCard(context, dishes[index], cartState);
        },
      ),
    );
  }

  Widget _buildGridDishCard(
    BuildContext context,
    FoodModel dish,
    CartState cartState,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        final restaurantName =
            (ref.read(restaurantViewModelProvider).restaurant ??
                    widget.restaurant)
                ?.name;
        FoodDetailSheet.show(context, dish, restaurantName: restaurantName);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                key: _dishImageKeys.putIfAbsent(dish.id, () => GlobalKey()),
                height: 140.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF0F0F0),
                ),
                clipBehavior: Clip.antiAlias,
                child: SmartImage(
                  url: dish.imageUrl,
                  category: ImageCategory.food,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              dish.isVeg ? _buildVegIcon(size: 10) : _buildNonVegIcon(size: 10),
              const Spacer(),
              if (dish.rating > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _priceGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: _priceGreen, size: 9.sp),
                      SizedBox(width: 2.w),
                      Text(
                        dish.reviewCount > 0
                            ? '${dish.rating} (${dish.reviewCount})'
                            : '${dish.rating}',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: _priceGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          SizedBox(
            height: 32.h,
            child: Text(
              dish.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${dish.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              _buildAddButton(context, dish, quantity, cartItemId),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleFirstAddToCart(FoodModel dish) async {
    Haptics.light();
    await addFoodToCart(context, ref, dish);
  }

  Widget _buildAddButton(
    BuildContext context,
    FoodModel dish,
    int quantity,
    String? cartItemId,
  ) {
    final hasQty = quantity > 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: !hasQty
          // ---- Simple + circle button ----
          ? GestureDetector(
              key: const ValueKey('add_circle'),
              onTap: () => _handleFirstAddToCart(dish),
              child: Container(
                width: 32.r,
                height: 32.r,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            )
          // ---- Stepper pill ----
          : Container(
              key: const ValueKey('stepper_pill'),
              height: 32.h,
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity - 1);
                          },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Icon(
                        Icons.remove_rounded,
                        color: Colors.white,
                        size: 15.sp,
                      ),
                    ),
                  ),
                  Text(
                    '$quantity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  GestureDetector(
                    onTap: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity + 1);
                          },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 15.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==================== FLOATING MENU BUTTON & CATEGORY BOTTOM SHEET ====================

  Widget _buildFloatingMenuButton(BuildContext context, RestaurantState state) {
    return GestureDetector(
      onTap: () {
        Haptics.medium();
        _showCategoryBottomSheet(context, state);
      },
      child: Container(
        width: 60.r,
        height: 60.r,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/menuicon.png',
              width: 20.sp,
              height: 20.sp,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.restaurant_menu, color: Colors.white, size: 20.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              'MENU',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, RestaurantState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = state.categories;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu Categories',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => Divider(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade200,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 4.h),
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${category.itemCount}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _onCategoryChipTap(category.id);
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        );
      },
    );
  }


  Widget _buildVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF008A45), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: (size * 0.4).sp,
        height: (size * 0.4).sp,
        decoration: const BoxDecoration(
          color: Color(0xFF008A45),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildNonVegIcon({double size = 10}) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE23744), width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size((size * 0.5).sp, (size * 0.5).sp),
        painter: _TrianglePainter(color: const Color(0xFFE23744)),
      ),
    );
  }
}

// Delegate for Sticky Persistent Search Bar (safely positioned below Status Bar)
class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double topPadding;

  _StickySearchBarDelegate({required this.child, required this.topPadding});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      padding: EdgeInsets.only(top: topPadding),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => 84.h + topPadding;

  @override
  double get minExtent => 84.h + topPadding;

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.topPadding != topPadding;
  }
}

// Delegate for the sticky category chip bar, pinned directly under the
// search bar so the active section stays visible while the menu scrolls.
class _StickyCategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double barHeight;

  _StickyCategoryBarDelegate({required this.child, required this.barHeight});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : Colors.white,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  double get maxExtent => barHeight;

  @override
  double get minExtent => barHeight;

  @override
  bool shouldRebuild(covariant _StickyCategoryBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.barHeight != barHeight;
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

