import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/auth_styles.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../providers/auth_flow_provider.dart';
import '../providers/scan_id_provider.dart';
import '../widgets/auth_back_button.dart';
import '../widgets/camera_controls.dart';
import '../widgets/id_viewfinder.dart';
import '../../../common/presentation/theme/app_system_ui.dart';

/// V1 · Scan photo ID — Figma node 1018:8233.
///
/// The shutter takes the selected side with the camera; "Choose from
/// library" picks it instead. Front / Back chips choose the side (or retake
/// one). No sheet pops up over the shutter. Once both sides are captured the photos are shown
/// for review on V3 and sent to `submit-identity-verification`.
class ScanPhotoIdScreen extends StatelessWidget {
  const ScanPhotoIdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthFlowProvider>.value(
          value: sl<AuthFlowProvider>(),
        ),
        ChangeNotifierProvider<ScanIdProvider>(
          create: (_) => sl<ScanIdProvider>(),
        ),
      ],
      child: const _ScanBody(),
    );
  }
}

class _ScanBody extends StatefulWidget {
  const _ScanBody();

  @override
  State<_ScanBody> createState() => _ScanBodyState();
}

class _ScanBodyState extends State<_ScanBody> {
  @override
  void initState() {
    super.initState();
    // Restore the saved name (lost after an app restart) for the ID check.
    context.read<AuthFlowProvider>().restoreFromProfile();
  }

  /// Front / Back chip: selects that side; the shutter or "Choose from
  /// library" then takes it (also to retake a side that has a photo).
  void _pickSide(IdSide side) {
    final scan = context.read<ScanIdProvider>();
    if (scan.isBusy) return;
    scan.selectSide(side);
  }

  /// Back: previous screen, or About you when this is the first screen
  /// (the app was reopened mid sign-up and started here).
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.aboutYou);
    }
  }

  Future<void> _capture(
    BuildContext context, {
    required bool fromCamera,
  }) async {
    final scan = context.read<ScanIdProvider>();
    final flow = context.read<AuthFlowProvider>();
    if (scan.isBusy) return;
    scan.setBusy(true);
    final error = await flow.captureIdSide(scan.side, fromCamera: fromCamera);
    scan.setBusy(false);
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);

    final frontDone = flow.idFrontPath != null;
    // A passport has no back side.
    final backDone = !flow.idNeedsBack || flow.idBackPath != null;
    scan.advance(frontDone: frontDone, backDone: backDone);
    if (flow.hasIdPhotos) {
      Navigator.pushNamed(context, AppRoutes.idVerified);
    }
  }

  /// Why the license is needed and how the photos are kept.
  void _showPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.screen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your ID photos', style: AppTextStyles.headingH3),
              const SizedBox(height: 12),
              for (final line in const [
                'Why: we confirm every parent who drives has a valid '
                    'license, and that the name matches your profile.',
                'Who sees it: only the KidsPool review team. Other parents '
                    'only see that you’re verified, never the photos.',
                'How it’s stored: in private, access-controlled storage, '
                    'never shared or sold.',
                'Deleting: the photos are deleted when you delete your '
                    'account (Profile › Delete account).',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(line, style: AppTextStyles.body),
                ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanIdProvider>();
    final flow = context.watch<AuthFlowProvider>();
    final frontDone = flow.idFrontPath != null;
    final backDone = !flow.idNeedsBack || flow.idBackPath != null;
    final idTypes = flow.allowedIdTypes;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.light,
      child: Scaffold(
        backgroundColor: AppColors.inverse,
        body: AppLoadingOverlay(
          isLoading: scan.isBusy,
          dark: true,
          child: Stack(
            children: [
              const Positioned.fill(child: _CameraView()),
              // The ID frame is centered on the screen (Figma: 425 of 844).
              const Align(
                alignment: Alignment(0, 0.01),
                child: FittedBox(fit: BoxFit.scaleDown, child: IdViewfinder()),
              ),
              SafeArea(
                // Scrolls on short phones; the tips and shutter stay at the
                // bottom on taller ones.
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
                              child: AuthBackButton(onPressed: _back),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Scan your\n',
                                      children: [
                                        TextSpan(
                                          text: idTypes.length > 1
                                              ? 'photo ID'
                                              : flow.idType.inSentence,
                                          style: TextStyle(
                                            color: AppColors.lime,
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: AppTextStyles.displayL.copyWith(
                                      color: AppColors.textOnDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    idTypes.length > 1
                                        ? 'We check your ID so families know who '
                                              'they’re riding with.'
                                        : 'Every parent who drives is checked, so '
                                              'families know their driver is licensed.',
                                    style: AppTextStyles.label.copyWith(
                                      color: AppColors.textOnDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _showPrivacy(context),
                                    child: Text(
                                      'Who sees it and how it’s stored',
                                      style: AppTextStyles.label.copyWith(
                                        color: AppColors.lime,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.lime,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Parents who only need rides pick their ID type.
                                  if (idTypes.length > 1) ...[
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (final type in idTypes) ...[
                                            DarkChoiceChip(
                                              label: type.label,
                                              selected: type == flow.idType,
                                              onTap: () {
                                                flow.setIdType(type);
                                                scan.selectSide(IdSide.front);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Row(
                                    children: [
                                      DarkChoiceChip(
                                        label: frontDone
                                            ? 'Front · done'
                                            : 'Front',
                                        selected: scan.side == IdSide.front,
                                        onTap: () => _pickSide(IdSide.front),
                                      ),
                                      if (flow.idNeedsBack) ...[
                                        const SizedBox(width: 8),
                                        DarkChoiceChip(
                                          label: flow.idBackPath != null
                                              ? 'Back · done'
                                              : 'Back',
                                          selected: scan.side == IdSide.back,
                                          onTap: () => _pickSide(IdSide.back),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Center(
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  CameraHintPill('Good light'),
                                  CameraHintPill('No glare'),
                                  CameraHintPill('All 4 corners'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Camera only here; the library is offered in the
                            // camera-or-library sheet for each side.
                            Center(
                              child: ShutterButton(
                                onPressed: () =>
                                    _capture(context, fromCamera: true),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton.icon(
                                onPressed: () =>
                                    _capture(context, fromCamera: false),
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  color: AppColors.textOnDark,
                                ),
                                label: Text(
                                  'Choose from library',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                scan.instruction(
                                  frontDone: frontDone,
                                  backDone: backDone,
                                ),
                                style: AuthTextStyles.labelM.copyWith(
                                  color: AppColors.textOnDarkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder camera feed: radial gradient from the Figma "Camera view".
class _CameraView extends StatelessWidget {
  const _CameraView();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          // 195px horizontally on a 390px frame, stretched vertically.
          radius: 0.5,
          transform: _VerticalStretch(703 / 195),
          colors: [
            AuthColors.cameraCenter,
            AuthColors.cameraMid,
            AppColors.inverse,
          ],
          stops: [0, 0.5, 1],
        ),
      ),
    );
  }
}

/// Scales a gradient vertically around the center of its bounds, turning a
/// circular radial gradient into the tall ellipse used in Figma.
class _VerticalStretch extends GradientTransform {
  const _VerticalStretch(this.factor);

  final double factor;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final center = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(1, factor, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}
