import 'package:flutter/material.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
import '../providers/driver_availability_provider.dart';

enum _MenuItem { notifications, logOut }

/// Home header menu: Notifications and Log out in a dropdown that fits its
/// items. A dot shows on the button and the row while there are unseen
/// notifications.
class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({
    super.key,
    required this.onNotifications,
    required this.onLogOut,
    this.hasUnseenNotifications = false,
    this.size = 48,
  });

  final VoidCallback onNotifications;
  final VoidCallback onLogOut;
  final bool hasUnseenNotifications;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_MenuItem>(
      tooltip: hasUnseenNotifications ? 'Menu, new notifications' : 'Menu',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: AppColors.screen,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: EdgeInsets.zero,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      onSelected: (item) => switch (item) {
        _MenuItem.notifications => onNotifications(),
        _MenuItem.logOut => onLogOut(),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuItem.notifications,
          height: 48,
          child: _MenuRow(
            leading: const AppIcon(HomeAssets.iconBell, size: 22),
            label: 'Notifications',
            dot: hasUnseenNotifications,
          ),
        ),
        const PopupMenuItem(
          value: _MenuItem.logOut,
          height: 48,
          child: _MenuRow(
            leading: Icon(
              Icons.power_settings_new_rounded,
              color: AppColors.ink,
              size: 22,
            ),
            label: 'Log out',
          ),
        ),
      ],
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.menu_rounded, color: AppColors.ink, size: 24),
              ),
            ),
            if (hasUnseenNotifications)
              Positioned(
                right: 0,
                top: 0,
                child: const IgnorePointer(
                  child: AppIcon(HomeAssets.alertDot, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.leading,
    required this.label,
    this.dot = false,
  });

  final Widget leading;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 12),
        Text(label, style: HomeTextStyles.labelM),
        if (dot) ...[
          const SizedBox(width: 8),
          const AppIcon(HomeAssets.alertDot, size: 10),
        ],
      ],
    );
  }
}

/// Ride Partner only: "Available" on/off. While off, no new ride requests
/// reach them; booked rides carry on as normal.
class AvailabilitySwitch extends StatelessWidget {
  const AvailabilitySwitch({super.key});

  Future<void> _toggle(
    BuildContext context,
    DriverAvailabilityProvider availability,
    bool value,
  ) async {
    final error = await availability.setAvailable(value);
    if (!context.mounted) return;
    showAppSnack(
      context,
      error ??
          (value
              ? 'You’re available. New ride requests will reach you.'
              : 'You’re off. No new ride requests until you turn this on.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availability = sl<DriverAvailabilityProvider>();
    return ListenableBuilder(
      listenable: availability,
      builder: (context, _) {
        final on = availability.available;
        return Semantics(
          toggled: on,
          label: 'Available for ride requests',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.only(left: 12, right: 4),
            decoration: BoxDecoration(
              color: on ? AppColors.limeTint : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(on ? 'Available' : 'Off', style: HomeTextStyles.labelM),
                const SizedBox(width: 4),
                Switch(
                  value: on,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeThumbColor: AppColors.ink,
                  activeTrackColor: AppColors.lime,
                  inactiveThumbColor: AppColors.screen,
                  inactiveTrackColor: AppColors.surfaceStrong,
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  onChanged: availability.busy
                      ? null
                      : (v) => _toggle(context, availability, v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
