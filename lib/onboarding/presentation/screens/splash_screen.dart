import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/constants/app_constants.dart';
import '../../../common/presentation/state/view_state.dart';
import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/app_version_provider.dart';

/// S01 · Splash. Checks the app version, then continues to sign-in or back
/// to where a signed-in user left off.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AppVersionProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppVersionProvider>()
      ..addListener(_onStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_provider.status.isInitial) _provider.fetchAppVersion();
      _onStatusChanged();
    });
  }

  @override
  void dispose() {
    _provider.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted || !_provider.status.isSuccess) return;
    if (_provider.isUpdateRequired) return; // Stay here: update message.
    Navigator.of(context).pushReplacementNamed(_provider.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppVersionProvider>();
    final busy = provider.status.isInitial || provider.status.isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.inverse,
        body: LayoutBuilder(
          builder: (context, constraints) {
            // The mark sits at the exact centre of the screen (not of the safe
            // area) so it lines up with the native launch screen on iOS and
            // Android; the wordmark and tagline hang below it.
            final centerY = constraints.maxHeight / 2;
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: centerY - _Logo.markSize / 2,
                  child: Center(child: _Logo.mark(animate: busy)),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: centerY + _Logo.markSize / 2 + 20,
                  child: const _Logo(),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 24),
                    child: _Footer(provider: provider),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.provider});

  final AppVersionProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.isUpdateRequired) ...[
          Text(
            provider.appVersion?.message ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyL.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 8),
          SelectableText(
            provider.appVersion?.storeUrl ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.lime),
          ),
          const SizedBox(height: 12),
        ],
        if (provider.status.isFailure) ...[
          Text(
            provider.errorMessage ?? '',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          TextButton(
            onPressed: provider.fetchAppVersion,
            child: Text(
              'Try again',
              style: AppTextStyles.label.copyWith(color: AppColors.lime),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'v${AppConstants.appDisplayVersion}',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textOnDarkMuted,
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  /// Figma "Mark": 104px lime square, 36px radius, 56px glyph.
  static const double markSize = 104;

  /// The app-icon mark; pulses (via [AppLoader]) while the app is loading.
  static Widget mark({required bool animate}) {
    if (animate) {
      // Same footprint as the static mark; the glow may overflow it.
      return const SizedBox.square(
        dimension: markSize,
        child: OverflowBox(
          maxWidth: markSize * 1.3,
          maxHeight: markSize * 1.3,
          child: AppLoader(size: markSize, semanticsLabel: 'Loading kidpool'),
        ),
      );
    }
    return Container(
      width: markSize,
      height: markSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: BorderRadius.circular(36),
        boxShadow: AppDimens.glowLime,
      ),
      child: const AppIcon(AppAssets.logoGlyph, size: 56),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'kidpool. Rides you can trust, from parents you know.',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'kidpool',
            textAlign: TextAlign.center,
            style: AppTextStyles.displayL.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: 20),
          Text(
            'Rides you can trust,\nfrom parents you know.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyL.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
