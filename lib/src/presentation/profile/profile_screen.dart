import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../../core/services/review_service.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../../data/models/user_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../coupons/viewmodels/coupons_viewmodel.dart';
import 'viewmodels/notifications_viewmodel.dart';
import '../orders/viewmodels/orders_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../wallet/viewmodels/pay_later_viewmodel.dart';
import '../branding/locale_provider.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../../core/utils/localizations.dart';
import '../branding/theme_color_provider.dart';
import '../branding/theme_provider.dart';
import '../home/viewmodels/veg_filter_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _getThemeString(ThemeMode mode) {
    if (mode == ThemeMode.light) return 'Light';
    if (mode == ThemeMode.dark) return 'Dark';
    return 'System';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;

    final user = ref.watch(authViewModelProvider).value;
    final isLoggedIn = user != null;

    final addresses = ref.watch(addressViewModelProvider);
    final coupons = ref.watch(couponsViewModelProvider);
    final notificationSettings = ref.watch(notificationsViewModelProvider);
    final walletState = isLoggedIn ? ref.watch(walletViewModelProvider) : null;
    final walletBalance = walletState?.wallet.balance ?? 0.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            // 1. Header
            _buildHeader(context, textColor, secondaryColor, isLoggedIn),

            const SizedBox(height: 20),

            // 2. User Profile Card / Guest Card
            if (isLoggedIn)
              _buildUserProfileCard(user, isDark, textColor, secondaryColor)
            else
              _buildGuestCard(context, isDark, textColor, secondaryColor),

            const SizedBox(height: 16),

            // 3. Wallet & Coupons Quick Row
            _buildWalletCouponsRow(
              walletBalance,
              coupons.length,
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 16),

            // 3b. Pay Later Tile
            if (isLoggedIn) ...[
              _buildPayLaterTile(cardColor, isDark, textColor, secondaryColor),
              const SizedBox(height: 16),
            ],

            // 4. Cart & Saved Addresses Quick Row
            _buildCartAddressesRow(
              addresses.length,
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 16),

            // 5. Account & Preferences Group
            _buildPreferencesGroupCard(
              notificationSettings,
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 16),

            // 6. Order History Card (Breakdown + View All)
            _buildOrderHistoryCard(
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 16),

            // 7. Rewards & Sharing Group
            _buildRewardsSharingGroupCard(
              user?.referralCode ?? '',
              cardColor,
              isDark,
              textColor,
              secondaryColor,
            ),

            const SizedBox(height: 16),

            // 8. Help, Support & Legal Group
            _buildHelpLegalGroupCard(
              cardColor,
              isDark,
              textColor,
              secondaryColor,
            ),

            const SizedBox(height: 20),

            // 9. Session Action (Logout or Login)
            if (isLoggedIn)
              _buildLogoutButton(cardColor, isDark)
            else
              _buildLoginButton(cardColor),

            if (isLoggedIn) ...[
              const SizedBox(height: 12),
              _buildDeleteAccountButton(),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Top Profile Header
  Widget _buildHeader(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.profile,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLoggedIn
                    ? AppLocalizations.of(context)!.profileSubtitle
                    : AppLocalizations.of(context)!.loginPromptOrders,
                style: TextStyle(fontSize: 13, color: secondaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// User Profile Card with Edit Profile action
  Widget _buildUserProfileCard(
    UserModel? user,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final avatarUrl = user?.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.primaryTintStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryAlpha(0.25), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: avatarUrl == null
                        ? ClipOval(
                            child: Image.asset(
                              'assets/images/user_avatar_3d.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 34,
                              ),
                            ),
                          )
                        : ClipOval(
                            child: avatarUrl.startsWith('/')
                                ? Image.file(File(avatarUrl), fit: BoxFit.cover)
                                : (avatarUrl.startsWith('assets/')
                                      ? Image.asset(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(
                                            Icons.person_rounded,
                                            color: AppColors.primary,
                                            size: 34,
                                          ),
                                        )),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.editProfile);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.phone ?? '',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Haptics.light();
                context.push(RouteNames.editProfile);
              },
              icon: Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              label: Text(
                AppLocalizations.of(context)!.editProfile,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Guest Card when logged out
  Widget _buildGuestCard(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.primaryTintStrong,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryAlpha(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.guestUser,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalizations.of(context)!.loginPromptDetails,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryColor,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Haptics.light();
                context.push(
                  '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.profile)}',
                );
              },
              child: Text(
                AppLocalizations.of(context)!.loginSignUp,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wallet & Coupons Row
  Widget _buildWalletCouponsRow(
    double walletBalance,
    int couponCount,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Wallet Tile
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.light();
                _protectedNavigation(RouteNames.wallet, isLoggedIn);
              },
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.wallet,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLoggedIn
                              ? '₹${walletBalance.toStringAsFixed(2)}'
                              : AppLocalizations.of(context)!.viewBalance,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 12),

          // Coupons Tile
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.light();
                _showCouponsModal();
              },
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.coupons,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.activeCoupons(couponCount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pay Later Tile
  Widget _buildPayLaterTile(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final payLater = ref.watch(payLaterViewModelProvider).account;
    final hasDue = payLater.amountDue > 0;
    final l10n = AppLocalizations.of(context)!;
    final subtitle = !payLater.eligible
        ? l10n.unlocksAfterOrders
        : hasDue
        ? l10n.payLaterDue('₹${payLater.amountDue.toStringAsFixed(0)}')
        : l10n.payLaterAvailable(
            '₹${payLater.availableCredit.toStringAsFixed(0)}',
          );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.push(RouteNames.payLater);
        },
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasDue
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.primaryAlpha(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.credit_score_outlined,
                color: hasDue ? AppColors.error : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.payLater,
                    style: TextStyle(fontSize: 11.5, color: secondaryColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: hasDue ? AppColors.error : textColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// My Cart & Saved Addresses Row
  Widget _buildCartAddressesRow(
    int addressCount,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          // My Cart Tile
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.light();
                context.go(RouteNames.cart);
              },
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.myCart,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.viewCart,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 12),

          // Saved Addresses Tile
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.light();
                if (isLoggedIn) {
                  _showAddressManagerModal();
                } else {
                  context.push(
                    '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.addAddress)}',
                  );
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.savedAddresses,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.savedCount(addressCount),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Account & Preferences Group
  Widget _buildPreferencesGroupCard(
    NotificationSettingsState notifSettings,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // 1. Notifications Preferences
          _buildMenuRow(
            icon: Icons.notifications_active_outlined,
            title: context.l10n.notificationsAndAlerts,
            subtitle: context.l10n.notificationsSubtitle,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: _showNotificationsModal,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 2. Veg Mode Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF39C96B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF39C96B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.vegMode,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.vegModeSubtitle,
                        style: TextStyle(fontSize: 12, color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: ref.watch(vegFilterProvider),
                  activeThumbColor: const Color(0xFF39C96B),
                  onChanged: (val) {
                    Haptics.light();
                    ref.read(vegFilterProvider.notifier).set(val);
                  },
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 3. Appearance
          _buildMenuRow(
            icon: Icons.palette_outlined,
            title: context.l10n.appearanceSettings,
            subtitle: context.l10n.appearanceThemeMode(
              _getThemeString(ref.watch(themeProvider)),
            ),
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: _showAppearanceModal,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 3b. App Theme (brand color)
          _buildMenuRow(
            icon: Icons.color_lens_outlined,
            title: context.l10n.appTheme,
            subtitle:
                '${ref.watch(themeColorProvider).emoji} ${ref.watch(themeColorProvider).label}',
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: _showThemeColorModal,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 3c. Language
          _buildMenuRow(
            icon: Icons.language_outlined,
            title: context.l10n.language,
            subtitle: ref.watch(localeProvider).languageCode == 'hi'
                ? 'हिन्दी'
                : 'English',
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: _showLanguageModal,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 4. Favorites
          _buildMenuRow(
            icon: Icons.favorite_border_rounded,
            title: context.l10n.favorites,
            subtitle: context.l10n.favoritesSubtitle,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () => context.push(RouteNames.favorites),
          ),
        ],
      ),
    );
  }

  /// Order History Summary Card
  Widget _buildOrderHistoryCard(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    // Watch the orders state — updates automatically when any order changes.
    final ordersState = ref.watch(ordersViewModelProvider);
    final upcoming = isLoggedIn ? ordersState.upcomingCount.toString() : '0';
    final completed = isLoggedIn ? ordersState.completedCount.toString() : '0';
    final cancelled = isLoggedIn ? ordersState.cancelledCount.toString() : '0';
    final refunded = isLoggedIn ? ordersState.refundedCount.toString() : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              InkWell(
                onTap: () =>
                    _protectedNavigation(RouteNames.orders, isLoggedIn),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All Orders',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _orderStat(
                Icons.shopping_bag_rounded,
                AppColors.primary,
                upcoming,
                'Upcoming',
                textColor,
                secondaryColor,
              ),
              _orderStat(
                Icons.check_circle_rounded,
                const Color(0xFF39C96B),
                completed,
                'Completed',
                textColor,
                secondaryColor,
              ),
              _orderStat(
                Icons.cancel_rounded,
                const Color(0xFFFF6464),
                cancelled,
                'Cancelled',
                textColor,
                secondaryColor,
              ),
              _orderStat(
                Icons.replay_circle_filled_rounded,
                AppColors.primary,
                refunded,
                'Refunds',
                textColor,
                secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderStat(
    IconData icon,
    Color color,
    String value,
    String label,
    Color textColor,
    Color secondaryColor,
  ) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11.5, color: secondaryColor)),
      ],
    );
  }

  /// Rewards & Sharing Group
  Widget _buildRewardsSharingGroupCard(
    String referralCode,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // 1. Refer & Earn
          _buildMenuRow(
            icon: Icons.card_giftcard_rounded,
            title: context.l10n.referAndEarn,
            subtitle: context.l10n.referralSubtitle(referralCode),
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () {
              Haptics.light();
              context.push(RouteNames.referral);
            },
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 2. Rate App
          _buildMenuRow(
            icon: Icons.star_border_rounded,
            title: context.l10n.rateApp,
            subtitle: context.l10n.rateAppSubtitle,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: _showRateAppModal,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),

          // 3. Share App
          _buildMenuRow(
            icon: Icons.share_outlined,
            title: context.l10n.shareApp,
            subtitle: context.l10n.shareAppSubtitle,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () {
              Haptics.light();
              Clipboard.setData(
                const ClipboardData(
                  text:
                      'Check out LAGECH app for delicious food delivery: https://www.lagech.in',
                ),
              );
              AppSnackbar.success(
                context,
                'App invite link copied to clipboard! 🚀',
                duration: const Duration(seconds: 2),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Help, Support & Legal Group
  Widget _buildHelpLegalGroupCard(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // 1. Help & Support
          _buildMenuRow(
            icon: Icons.headset_mic_outlined,
            title: context.l10n.helpSupport,
            subtitle: context.l10n.helpSupportSubtitle,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () => context.push(RouteNames.helpSupport),
          ),
        ],
      ),
    );
  }

  /// Reusable Menu Row with right arrow chevron navigation indicator
  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: secondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _protectedNavigation(String targetRoute, bool isLoggedIn) {
    if (isLoggedIn) {
      context.push(targetRoute);
    } else {
      context.push(
        '${RouteNames.login}?from=${Uri.encodeComponent(targetRoute)}',
      );
    }
  }

  /// Log Out Button
  Widget _buildLogoutButton(Color cardColor, bool isDark) {
    return InkWell(
      onTap: () {
        Haptics.medium();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.logOut),
            content: Text(context.l10n.logOutMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 226, 32, 32),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authViewModelProvider.notifier).logout();
                  if (mounted) {
                    AppSnackbar.success(
                      context,
                      'Logged out successfully',
                      duration: const Duration(seconds: 2),
                    );
                  }
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: Color.fromARGB(255, 219, 32, 32),
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                color: Color.fromARGB(255, 215, 21, 21),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Log In Button
  Widget _buildLoginButton(Color cardColor) {
    return InkWell(
      onTap: () {
        Haptics.light();
        context.push(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.profile)}',
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Log In to Account',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Delete Account Button — destructive action, requires typed confirmation.
  Widget _buildDeleteAccountButton() {
    return InkWell(
      onTap: () {
        Haptics.medium();
        _showDeleteAccountDialog();
      },
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_forever_outlined,
              color: Color.fromARGB(255, 250, 29, 29),
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(
                color: Color.fromARGB(255, 220, 23, 23),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm =
              confirmController.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Text(context.l10n.deleteAccount),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.deleteAccountMessage),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.typeDeleteToConfirm,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).hintColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmController,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 241, 34, 34),
                ),
                onPressed: canConfirm
                    ? () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(authViewModelProvider.notifier)
                            .deleteAccount();
                        if (!mounted) return;
                        if (ok) {
                          AppSnackbar.success(
                            context,
                            'Account deleted',
                            duration: const Duration(seconds: 2),
                          );
                        } else {
                          AppSnackbar.error(
                            context,
                            ref
                                    .read(authViewModelProvider.notifier)
                                    .lastError ??
                                'Could not delete account. Please try again.',
                          );
                        }
                      }
                    : null,
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // DYNAMIC INTERACTIVE MODALS & BOTTOM SHEETS
  // ==========================================

  void _showAddressManagerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final addresses = ref.watch(addressViewModelProvider);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Addresses 📍',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: addresses.length,
                  itemBuilder: (context, i) {
                    final addr = addresses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        leading: Icon(
                          addr.type == 'Home'
                              ? Icons.home_rounded
                              : (addr.type == 'Work'
                                    ? Icons.work_rounded
                                    : Icons.location_on_rounded),
                          color: AppColors.primary,
                        ),
                        title: Row(
                          children: [
                            Text(
                              addr.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (addr.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAlpha(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'DEFAULT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          addr.fullAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            Haptics.light();
                            ref
                                .read(addressViewModelProvider.notifier)
                                .deleteAddress(addr.id);
                          },
                        ),
                        onTap: () {
                          Haptics.light();
                          ref
                              .read(addressViewModelProvider.notifier)
                              .setDefaultAddress(addr.id);
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButton,
                  ),
                  onPressed: () {
                    Haptics.light();
                    Navigator.pop(ctx);
                    context.push(RouteNames.addAddress);
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add New Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCouponsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final coupons = ref.watch(couponsViewModelProvider);

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Coupons 🏷️',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: coupons.length,
                  itemBuilder: (context, i) {
                    final c = coupons[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryAlpha(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c.code,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.discountText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.description,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Haptics.light();
                                Clipboard.setData(ClipboardData(text: c.code));
                                Navigator.pop(ctx);
                                AppSnackbar.success(
                                  context,
                                  'Coupon code ${c.code} copied!',
                                );
                              },
                              child: Text(
                                'COPY',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final notifSettings = ref.watch(notificationsViewModelProvider);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notification Preferences 🔔',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(context.l10n.orderStatusAlerts),
                    value: notifSettings.orderStatus,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      Haptics.light();
                      ref
                          .read(notificationsViewModelProvider.notifier)
                          .toggleOrderStatus(val);
                    },
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.promoAlerts),
                    value: notifSettings.promoOffers,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      Haptics.light();
                      ref
                          .read(notificationsViewModelProvider.notifier)
                          .togglePromoOffers(val);
                    },
                  ),
                  SwitchListTile(
                    title: Text(context.l10n.soundHapticAlerts),
                    value: notifSettings.soundAlerts,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) {
                      Haptics.light();
                      ref
                          .read(notificationsViewModelProvider.notifier)
                          .toggleSoundAlerts(val);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAppearanceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Theme Appearance 🎨',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _themeOptionTile(
                ctx,
                'Light Mode',
                'Light',
                Icons.wb_sunny_outlined,
              ),
              _themeOptionTile(
                ctx,
                'Dark Mode',
                'Dark',
                Icons.dark_mode_outlined,
              ),
              _themeOptionTile(
                ctx,
                'System Default',
                'System',
                Icons.settings_brightness_outlined,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLanguageModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.selectLanguage,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _languageOptionTile(ctx, 'English', 'en'),
              _languageOptionTile(ctx, 'हिन्दी (Hindi)', 'hi'),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOptionTile(
    BuildContext ctx,
    String label,
    String languageCode,
  ) {
    final isSelected = ref.watch(localeProvider).languageCode == languageCode;
    return ListTile(
      leading: Icon(
        Icons.language_outlined,
        color: isSelected ? AppColors.primary : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: () {
        Haptics.light();
        ref.read(localeProvider.notifier).setLocale(languageCode);
        Navigator.pop(ctx);
      },
    );
  }

  void _showThemeColorModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'App Theme 🎨',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.pickBrandColor,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, _) {
                  final selected = ref.watch(themeColorProvider);
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: AppThemeColor.values.map((option) {
                      final isSelected = option == selected;
                      return GestureDetector(
                        onTap: () {
                          Haptics.light();
                          ref
                              .read(themeColorProvider.notifier)
                              .setColor(option);
                          Navigator.pop(ctx);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: option.color.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOptionTile(
    BuildContext ctx,
    String label,
    String value,
    IconData icon,
  ) {
    final currentThemeValue = _getThemeString(ref.watch(themeProvider));
    final isSelected = currentThemeValue == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: () {
        Haptics.light();
        ref.read(themeProvider.notifier).setTheme(value);
        Navigator.pop(ctx);
      },
    );
  }

  void _showRateAppModal() {
    int rating = 5;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enjoying LAGECH? ⭐',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap a star to rate your experience',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                        onPressed: () {
                          Haptics.light();
                          setSheetState(() => rating = index + 1);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButton,
                      ),
                      onPressed: () {
                        Haptics.success();
                        Navigator.pop(ctx);
                        AppSnackbar.success(
                          context,
                          'Thank you for giving us $rating stars! ❤️',
                        );
                        ReviewService.requestReviewIfQualified(rating);
                      },
                      child: const Text(
                        'Submit Rating',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
