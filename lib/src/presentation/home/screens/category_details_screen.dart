import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/restaurant_providers.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../widgets/restaurant_card.dart';

final categoryFoodsProvider =
    FutureProvider.family<List<FoodModel>, CategoryModel>((
      ref,
      category,
    ) async {
      final repo = ref.watch(restaurantRepositoryProvider);
      final res = await repo.getFoodsByCategory(
        category.id,
        categoryName: category.name,
        realCategoryId: category.id,
      );
      if (res.isSuccess) {
        return res.data ?? [];
      }
      return [];
    });

final categoryRestaurantsProvider =
    FutureProvider.family<List<RestaurantModel>, CategoryModel>((
      ref,
      category,
    ) async {
      final repo = ref.watch(restaurantRepositoryProvider);

      // 1. Direct category query from repository (uses backend unified search)
      final res = await repo.getRestaurantsByCategory(category);
      if (res.isSuccess && (res.data ?? []).isNotEmpty) {
        return res.data!;
      }

      // 2. High-precision fallback: Lookup restaurants from the dishes loaded in this category
      try {
        final foodsAsync = await ref.watch(categoryFoodsProvider(category).future);
        if (foodsAsync.isNotEmpty) {
          final restIds = foodsAsync
              .map((f) => f.restaurantId)
              .where((id) => id.isNotEmpty)
              .toSet();

          if (restIds.isNotEmpty) {
            final allRestsRes = await repo.getPopularRestaurants();
            if (allRestsRes.isSuccess && allRestsRes.data != null) {
              final matched = allRestsRes.data!
                  .where((r) => restIds.contains(r.id))
                  .toList();
              if (matched.isNotEmpty) return matched;
            }
          }
        }
      } catch (_) {}

      // 3. Fallback for Italian/cuisines (e.g. Pasta)
      if (category.name.toLowerCase().contains('pasta')) {
        final allRestsRes = await repo.getPopularRestaurants();
        if (allRestsRes.isSuccess && allRestsRes.data != null) {
          final italian = allRestsRes.data!.where((r) {
            final cuisines = r.tags.map((t) => t.toLowerCase()).toList();
            return cuisines.contains('italian') ||
                cuisines.contains('continental') ||
                r.name.toLowerCase().contains('cafe') ||
                r.name.toLowerCase().contains('pizza');
          }).toList();
          if (italian.isNotEmpty) return italian;
        }
      }

      return res.data ?? [];
    });

class CategoryDetailsScreen extends ConsumerStatefulWidget {
  final CategoryModel category;

  const CategoryDetailsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryDetailsScreen> createState() =>
      _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends ConsumerState<CategoryDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20.sp,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.category.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 24.sp,
            ),
            onPressed: () {
              Haptics.light();
              context.push(RouteNames.search, extra: widget.category.name);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.shopping_cart_outlined,
              color: isDark ? Colors.white : Colors.black,
              size: 24.sp,
            ),
            onPressed: () {
              Haptics.light();
              context.push(RouteNames.cart);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.sort_rounded,
              color: isDark ? Colors.white : Colors.black,
              size: 24.sp,
            ),
            onPressed: () {
              Haptics.light();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Pill Row
              Padding(
                padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 12.h, bottom: 6.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: const Color(0xFFE52020),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFE52020),
                  indicatorWeight: 3.h,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFFE52020),
                  unselectedLabelColor: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF8E8E93),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                  tabs: const [
                    Tab(text: 'Item'),
                    Tab(text: 'Restaurants'),
                  ],
                ),
              ),

              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildItemsTab(isDark),
                    _buildRestaurantsTab(isDark),
                  ],
                ),
              ),
            ],
          ),

          // Floating Cart Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingViewCartBar(
              key: _cartBarKey,
              bottomOffset: 12.h,
              onTap: () {
                Haptics.light();
                context.push(RouteNames.cart);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab(bool isDark) {
    final foodsAsync = ref.watch(categoryFoodsProvider(widget.category));

    return foodsAsync.when(
      data: (foods) {
        if (foods.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fastfood_outlined,
                    size: 64.sp,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No items found in ${widget.category.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Please check back later or explore other categories',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 14.h,
            bottom: 80.h,
          ),
          itemCount: foods.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final food = foods[index];
            return _buildFoodCard(food, isDark);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE52020)),
      ),
      error: (e, st) => Center(
        child: Text(
          'No items found',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantsTab(bool isDark) {
    final restaurantsAsync = ref.watch(
      categoryRestaurantsProvider(widget.category),
    );

    return restaurantsAsync.when(
      data: (restaurants) {
        if (restaurants.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 64.sp,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No restaurants found for ${widget.category.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Currently no restaurants are serving ${widget.category.name}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 14.h,
            bottom: 80.h,
          ),
          itemCount: restaurants.length,
          separatorBuilder: (context, index) => SizedBox(height: 14.h),
          itemBuilder: (context, index) {
            final r = restaurants[index];
            return RestaurantCard(
              restaurant: r,
              index: index,
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE52020)),
      ),
      error: (e, st) => Center(
        child: Text(
          'No restaurants found',
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodCard(FoodModel food, bool isDark) {
    final displayImage = food.imageUrl.isNotEmpty
        ? food.imageUrl
        : (food.imageGallery.firstOrNull ?? '');

    return GestureDetector(
      onTap: () {
        Haptics.light();
        context.push(RouteNames.foodDetail, extra: food);
      },
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image with rounded corners and heart icon overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: SmartImage(
                    url: displayImage,
                    category: ImageCategory.food,
                    width: 95.w,
                    height: 95.h,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6.r,
                  left: 6.r,
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 15.sp,
                      color: const Color(0xFFE57373),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Veg/NonVeg Indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.all(2.r),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: food.isVeg
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: Icon(
                          Icons.circle,
                          color: food.isVeg
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          size: 7.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),

                  // Restaurant Name
                  if (food.restaurantName.isNotEmpty) ...[
                    Text(
                      food.restaurantName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                  ],

                  // Price
                  Text(
                    '₹ ${food.price.toInt()}',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // + Add Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () async {
                        Haptics.light();
                        await addFoodToCart(context, ref, food);
                      },
                      borderRadius: BorderRadius.circular(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 7.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE52020),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '+ Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
