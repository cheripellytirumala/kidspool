import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/ride_tracking_assets.dart';
import 'ride_buttons.dart';

/// Empty / error / closed state for ride-day screens.
class RideStateView extends StatelessWidget {
  const RideStateView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.dark = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: dark ? AppColors.inverse : AppColors.screen,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: navigator.canPop()
                          ? RideIconButton.back(onPressed: navigator.maybePop)
                          : const SizedBox(height: 56),
                    ),
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const AppIcon(RideTrackingAssets.car, size: 36),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingH3.copyWith(
                        color: dark ? AppColors.textOnDark : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: dark ? AppColors.textOnDarkMuted : null,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: AppDimens.sectionGap),
                    if (onRetry != null) ...[
                      AppButton(label: 'Try again', onPressed: onRetry),
                      const SizedBox(height: 12),
                    ],
                    if (navigator.canPop())
                      AppButton(
                        label: 'Back',
                        variant: AppButtonVariant.light,
                        onPressed: navigator.maybePop,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
