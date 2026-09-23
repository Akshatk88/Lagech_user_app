import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';

/// Quick preview bottom sheet for food items matching the clean popup design.
///
/// Features:
/// - Food image on the left with rounded corners
/// - Dish title, Close 'X' button, restaurant name
/// - "Dish" and "Ready near you" badges
/// - "Price" label and bold amount
/// - Circular orange add button / quantity stepper
class FoodDetailSheet {
  const FoodDetailSheet._();

  static Future<void> show(
    BuildContext context,
    FoodModel food, {
    VoidCallback? onAdded,
    String? restaurantName,
    CartItemModel? existingCartItem,
    bool autoScrollToOptions = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodQuickDetailSheet(
        food: food,
        onAdded: onAdded,
        restaurantName: restaurantName,
        existingCartItem: existingCartItem,
      ),
    );
  }
}

class _FoodQuickDetailSheet extends ConsumerStatefulWidget {
  final FoodModel food;
  final VoidCallback? onAdded;
  final String? restaurantName;
  final CartItemModel? existingCartItem;

  const _FoodQuickDetailSheet({
    required this.food,
    this.onAdded,
    this.restaurantName,
    this.existingCartItem,
  });

  @override
  ConsumerState<_FoodQuickDetailSheet> createState() =>
      _FoodQuickDetailSheetState();
}

class _FoodQuickDetailSheetState extends ConsumerState<_FoodQuickDetailSheet> {
  String _getRestaurantName() {
    if (widget.restaurantName != null &&
        widget.restaurantName!.trim().isNotEmpty) {
      return widget.restaurantName!.trim();
    }
    if (widget.food.restaurantName.trim().isNotEmpty) {
      return widget.food.restaurantName.trim();
    }
    final rests =
        ref.read(homeViewModelProvider).nearbyRestaurants.asData?.value;
    if (rests != null) {
      final match = rests
          .where((r) => r.id == widget.food.restaurantId)
          .firstOrNull;
      if (match != null && match.name.isNotEmpty) {
        return match.name;
      }
    }
    if (widget.food.categoryName.trim().isNotEmpty) {
      return widget.food.categoryName.trim();
    }
    return 'Restaurant';
  }

  Future<void> _handleAddToCart() async {
    Haptics.light();
    await addFoodToCart(context, ref, widget.food);
    widget.onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B);

    final cartState = ref.watch(cartViewModelProvider);
    int quantity = 0;
    String? cartItemId;
    for (final item in cartState.items) {
      if (item.food.id == food.id) {
        quantity = item.quantity;
        cartItemId = item.id;
        break;
      }
    }
    final hasQty = quantity > 0;
    final restaurantName = _getRestaurantName();

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Center drag handle
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // 2. Middle Row: Food Image on Left, Details on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Food Image
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push(RouteNames.foodDetail, extra: food);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: SmartImage(
                        url: food.imageUrl,
                        category: ImageCategory.food,
                        width: 112.w,
                        height: 112.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 14.w),

                  // Right: Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dish Name + Close 'X' Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.push(
                                    RouteNames.foodDetail,
                                    extra: food,
                                  );
                                },
                                child: Text(
                                  food.name,
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(16.r),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 4.w,
                                  bottom: 4.h,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 22.sp,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),

                        // Restaurant Name
                        Text(
                          restaurantName,
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.h),

                        // Badge 1: "Dish"
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1B3828)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 13.sp,
                                color: const Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'Dish',
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),

                        // Badge 2: "Ready near you"
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1B3828)
                                : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 13.sp,
                                color: const Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                food.deliveryTime.isNotEmpty &&
                                        food.deliveryTime.contains('min')
                                    ? 'Ready in ${food.deliveryTime}'
                                    : 'Ready near you',
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // 3. Bottom Row: Price on Left, Circular Add / Stepper on Right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Price',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '₹${food.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),

                  // Circular Orange Add Button or Stepper
                  if (!hasQty)
                    InkWell(
                      key: const ValueKey('sheet_add_btn'),
                      onTap: _handleAddToCart,
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        width: 38.r,
                        height: 38.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          color: surfaceColor,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 32.h,
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: cartItemId == null
                                ? null
                                : () {
                                    Haptics.light();
                                    ref
                                        .read(cartViewModelProvider.notifier)
                                        .updateQuantity(
                                          cartItemId!,
                                          quantity - 1,
                                        );
                                  },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: Icon(
                                Icons.remove,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Text(
                              '$quantity',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: cartItemId == null
                                ? null
                                : () {
                                    Haptics.light();
                                    ref
                                        .read(cartViewModelProvider.notifier)
                                        .updateQuantity(
                                          cartItemId!,
                                          quantity + 1,
                                        );
                                  },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: Icon(
                                Icons.add,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
