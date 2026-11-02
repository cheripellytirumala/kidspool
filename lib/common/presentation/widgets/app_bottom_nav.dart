import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/router/app_routes.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Tabs of the main bottom navigation (shared by Home, Profile, …).
enum AppTab { home, messages, rides, profile }

/// Figma "Bottom Nav": four 80px circular items on a white fade so content
/// scrolls beneath. Active tab is lime.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current, this.onSelected});

  final AppTab current;

  /// Overrides the default tab navigation.
  final ValueChanged<AppTab>? onSelected;

  /// Route for each tab; `null` = not built yet (tab is inert).
  static String? routeOf(AppTab tab) => switch (tab) {
    AppTab.home => AppRoutes.home,
    AppTab.profile => AppRoutes.profile,
    AppTab.messages || AppTab.rides => null,
  };

  void _defaultSelect(BuildContext context, AppTab tab) {
    final route = routeOf(tab);
    if (route == null) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  static const double _itemSize = 80;
  static const double _horizontalPadding = 16;

  /// Height of the bar above the bottom safe area, for content padding.
  static const double height = 112;

  @override
  Widget build(BuildContext context) {
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
          _horizontalPadding,
          8,
          _horizontalPadding,
          math.max(24, bottomInset),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Shrink items on narrow phones so four always fit with a gap.
            final size = math.min(
              _itemSize,
              (constraints.maxWidth - 3 * 6) / AppTab.values.length,
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final tab in AppTab.values)
                  _NavItem(
                    tab: tab,
                    size: size,
                    active: tab == current,
                    onTap: onSelected != null
                        ? () => onSelected!(tab)
                        : routeOf(tab) == null
                        ? null
                        : () => _defaultSelect(context, tab),
                  ),
              ],
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
  });

  final AppTab tab;
  final double size;
  final bool active;
  final VoidCallback? onTap;

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
    return Semantics(
      selected: active,
      button: true,
      label: label,
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
  }
}
