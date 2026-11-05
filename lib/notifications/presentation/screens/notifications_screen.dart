import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../home/presentation/widgets/circle_icon_button.dart';
import '../../../messages/presentation/screens/ride_request_detail_screen.dart';
import '../../core/constants/notifications_assets.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_tile.dart';

/// F25b · Notifications — opened from the Home bell.
///
/// Rows come from `get_my_notifications` (ride updates for the user's own
/// requests, and requests / offer results as a Ride Partner). Rows newer
/// than the last visit are lime-soft; opening the list clears the bell dot.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationsProvider>(
      create: (_) => sl<NotificationsProvider>()..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  /// Display/L — 44/44 Regular, -1.32.
  static final TextStyle _heading = AppTextStyles.displayL;

  /// Where a row leads; null when there is nothing to open.
  static (String, Object)? _target(AppNotification n) {
    final id = n.requestId;
    if (id == null) return null;
    return switch (n.kind) {
      NotificationKind.rideConfirmed ||
      NotificationKind.rideStarted ||
      NotificationKind.pickedUp => (AppRoutes.liveTracking, RideArgs(id)),
      NotificationKind.rideArrived => (AppRoutes.rideCompleted, RideArgs(id)),
      NotificationKind.rideRequest => (
        AppRoutes.rideRequestDetail,
        RideRequestArgs(requestId: id),
      ),
      NotificationKind.driverCancelled ||
      NotificationKind.rideMissed ||
      NotificationKind.rideExpired => (
        AppRoutes.rideRequestDetail,
        RideRequestArgs(requestId: id, isMine: true),
      ),
      // The parent picked someone else: nothing left to act on.
      NotificationKind.offerDeclined || NotificationKind.other => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.screen,
        body: AppLoadingOverlay(
          isLoading: provider.isLoading,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: CircleIconButton(
                    asset: NotificationsAssets.arrowLeft,
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: provider.load,
                    color: AppColors.ink,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + bottomInset),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Semantics(
                            header: true,
                            child: Text('Notifications', style: _heading),
                          ),
                        ),
                        if (provider.showError)
                          _Message(
                            title: 'Couldn’t load notifications',
                            body: provider.errorMessage ?? '',
                            onRetry: provider.load,
                          )
                        else if (provider.showEmpty)
                          const _Message(
                            title: 'You’re all caught up',
                            body:
                                'Ride updates and requests from other '
                                'parents will show up here.',
                          ),
                        for (final n in provider.items) ...[
                          const SizedBox(height: 12),
                          NotificationTile(
                            notification: n,
                            isNew: provider.isNew(n),
                            onTap: switch (_target(n)) {
                              (final route, final args) =>
                                () => Navigator.pushNamed(
                                  context,
                                  route,
                                  arguments: args,
                                ),
                              null => null,
                            },
                          ),
                        ],
                      ],
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

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(body, style: AppTextStyles.body),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                backgroundColor: AppColors.surface,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Text('Try again', style: AppTextStyles.label),
            ),
          ],
        ],
      ),
    );
  }
}
