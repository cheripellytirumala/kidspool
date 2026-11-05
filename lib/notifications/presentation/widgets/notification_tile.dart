import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/notifications_assets.dart';
import '../../core/utils/notification_time.dart';
import '../../domain/entities/app_notification.dart';

/// F25b "Notif · …" row: 40px leading circle, title + subtitle, time.
/// New rows use lime-soft, older ones the surface grey.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.isNew,
    this.onTap,
  });

  final AppNotification notification;
  final bool isNew;
  final VoidCallback? onTap;

  /// Label/L — 16/20 SemiBold, -0.08.
  static final TextStyle _title = AppTextStyles.label.copyWith(
    height: 20 / 16,
    letterSpacing: -0.08,
  );

  /// Label/S — 12/16 Medium, secondary.
  static final TextStyle _meta = AppTextStyles.caption.copyWith(
    fontSize: 12,
    height: 16 / 12,
  );

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final time = NotificationTime.label(n.createdAt);
    return Semantics(
      button: onTap != null,
      label: [
        if (isNew) 'New',
        n.title,
        ?n.body,
        NotificationTime.spoken(n.createdAt),
      ].join('. '),
      excludeSemantics: true,
      child: Material(
        color: isNew ? AppColors.limeTint : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Leading(notification: n),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: _title),
                      if (n.body != null) ...[
                        const SizedBox(height: 2),
                        Text(n.body!, style: _meta),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(time, style: _meta),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White circle with a 19px icon, or the other parent's initials (the
/// design's "Photo · JP" slot — the API shares no photos here).
class _Leading extends StatelessWidget {
  const _Leading({required this.notification});

  final AppNotification notification;

  String? get _icon => switch (notification.kind) {
    NotificationKind.rideRequest => NotificationsAssets.inbox,
    NotificationKind.rideStarted ||
    NotificationKind.pickedUp ||
    NotificationKind.rideArrived => NotificationsAssets.pin,
    NotificationKind.rideConfirmed || NotificationKind.offerDeclined =>
      notification.otherInitials == null ? NotificationsAssets.bell : null,
    _ => NotificationsAssets.bell,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: icon == null ? AppColors.lime : AppColors.screen,
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? AppIcon(icon, size: 19)
          : Text(
              notification.otherInitials!,
              style: AppTextStyles.label.copyWith(fontSize: 14),
            ),
    );
  }
}
