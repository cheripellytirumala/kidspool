import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_routes.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../state/nav_badges.dart';

/// Tabs of the main bottom navigation (shared by Home, Profile, …).
enum AppTab { home, messages, rides, profile }

/// Figma "Bottom Nav": four 80px circular items on a white fade so content
/// scrolls beneath. Active tab is lime.
class AppBottomNav extends StatefulWidget {
  const AppBottomNav({super.key, required this.current, this.onSelected});

  final AppTab current;

  /// Overrides the default tab navigation.
  final ValueChanged<AppTab>? onSelected;

  /// Route for each tab; `null` = not built yet (tab is inert).
  static String? routeOf(AppTab tab) => switch (tab) {
    AppTab.home => AppRoutes.home,
    AppTab.messages => AppRoutes.messages,
    AppTab.profile => AppRoutes.profile,
    AppTab.rides => null,
  };

  static const double _itemSize = 80;
  static const double _horizontalPadding = 16;

  /// Height of the bar above the bottom safe area, for content padding.
  static const double height = 112;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  @override
  void initState() {
    super.initState();
    // Each tab screen builds its own bar: recount the Messages badge when a
    // tab opens (throttled in NavBadges).
    NavBadges.instance.refresh();
  }

  void _defaultSelect(BuildContext context, AppTab tab) {
    final route = AppBottomNav.routeOf(tab);
    if (route == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final onSelected = widget.onSelected;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), AppColors.screen],
          stops: [0, 0.35],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppBottomNav._horizontalPadding,
          8,
          AppBottomNav._horizontalPadding,
          math.max(24, bottomInset),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Shrink items on narrow phones so four always fit with a gap.
            final size = math.min(
              AppBottomNav._itemSize,
              (constraints.maxWidth - 3 * 6) / AppTab.values.length,
            );
            return ValueListenableBuilder<int>(
              valueListenable: NavBadges.instance.messages,
              builder: (context, unread, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final tab in AppTab.values)
                    _NavItem(
                      tab: tab,
                      size: size,
                      active: tab == current,
                      badge: tab == AppTab.messages ? unread : 0,
                      onTap: onSelected != null
                          ? () => onSelected(tab)
                          : AppBottomNav.routeOf(tab) == null
                          ? null
                          : () => _defaultSelect(context, tab),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.size,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final AppTab tab;
  final double size;
  final bool active;
  final VoidCallback? onTap;

  /// Red count at the top right (Messages); hidden when 0.
  final int badge;

  (String, String, EdgeInsets) get _spec => switch (tab) {
    // Icon groups are positioned inside a 24px frame as in Figma.
    AppTab.home => (
      'Home',
      AppAssets.iconHome,
      const EdgeInsets.fromLTRB(2.5, 2.8, 2.5, 3),
    ),
    AppTab.messages => ('Messages', AppAssets.iconChat, EdgeInsets.zero),
    AppTab.rides => (
      'Rides',
      AppAssets.iconCar,
      const EdgeInsets.fromLTRB(2.5, 5, 2.5, 4.35),
    ),
    AppTab.profile => (
      'Profile',
      AppAssets.iconUser,
      const EdgeInsets.fromLTRB(4, 3.5, 4, 3),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (label, icon, iconInset) = _spec;
    final item = Semantics(
      selected: active,
      button: true,
      label: badge > 0 ? '$label, $badge new' : label,
      excludeSemantics: true,
      child: Material(
        color: active ? AppColors.lime : AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: active ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: Padding(
                    padding: iconInset,
                    child: SvgPicture.asset(icon),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (badge <= 0) return item;
    // Figma: 28px circle at (53.3, -2) on the 80px item.
    final scale = size / AppBottomNav._itemSize;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        item,
        Positioned(
          left: 53.33 * scale,
          top: -2 * scale,
          child: IgnorePointer(child: _CountBadge(badge)),
        ),
      ],
    );
  }
}

/// Figma Messages badge: #FF4D3D with a 2px white ring, 12/20 SemiBold.
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.badge,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.screen, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.caption.copyWith(
          fontSize: 12,
          height: 20 / 12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.06,
          color: AppColors.textOnDark,
        ),
      ),
    );
  }
}
