import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../providers/kids_provider.dart';
import '../widgets/icon_disc.dart';
import '../widgets/kid_avatar.dart';
import '../widgets/kids_scaffold.dart';

/// F12 · You’re all set (Figma 1018:9211): dark summary of the kids and
/// their places; "Go to Dashboard" clears the onboarding stack.
class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kids = sl<KidsProvider>();
    // No-op once loaded; covers opening this screen directly.
    Future.microtask(kids.load);
    return ChangeNotifierProvider<KidsProvider>.value(
      value: kids,
      child: const _AllSetView(),
    );
  }
}

class _AllSetView extends StatelessWidget {
  const _AllSetView();

  @override
  Widget build(BuildContext context) {
    final kids = context.watch<KidsProvider>();

    return AppLoadingOverlay(
      isLoading: kids.isLoading,
      dark: true,
      child: KidsScaffold(
        backgroundColor: AppColors.inverse,
        showBack: false,
        topPadding: 4,
        gap: 12,
        title: kids.parentFirstName.isEmpty
            ? 'You’re all set'
            : 'You’re all set, ${kids.parentFirstName}',
        subtitle:
            'Find families near you go to the same places as your kids. '
            'Say hi and plan rides together.',
        above: const [
          SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: IconDisc(
              asset: KidsAssets.check,
              size: 88,
              iconSize: 40,
              color: AppColors.lime,
            ),
          ),
        ],
        bottom: AppButton(
          label: 'Go to Dashboard',
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
        ),
        children: [
          for (final child in kids.children)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              decoration: BoxDecoration(
                color: KidsColors.inverseRaised,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                spacing: 12,
                children: [
                  KidAvatar(child: child, size: 40),
                  Expanded(
                    child: Text(
                      '${child.firstName} · ${kids.placesCountLabel(child.id)}',
                      style: KidsTextStyles.labelL.copyWith(
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
