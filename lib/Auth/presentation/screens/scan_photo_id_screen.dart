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

/// V1 · Scan photo ID — Figma node 1018:8233.
///
/// The shutter opens the camera for the selected side and the gallery button
/// picks a photo instead. Once both sides are captured the photos are shown
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
    // On landing, ask right away whether to take or pick the photo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askSource());
  }

  /// "Take a photo" / "Choose from library" for the current side; skipped
  /// once that side already has a photo (e.g. coming back from V3).
  Future<void> _askSource() async {
    if (!mounted) return;
    final scan = context.read<ScanIdProvider>();
    final flow = context.read<AuthFlowProvider>();
    final done = scan.side == IdSide.front
        ? flow.idFrontPath != null
        : flow.idBackPath != null;
    if (done || scan.isBusy) return;
    final fromCamera = await showPhotoSourceSheet(context);
    if (fromCamera == null || !mounted) return;
    await _capture(context, fromCamera: fromCamera);
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
    final backDone = flow.idBackPath != null;
    scan.advance(frontDone: frontDone, backDone: backDone);
    if (frontDone && backDone) {
      Navigator.pushNamed(context, AppRoutes.idVerified);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanIdProvider>();
    final flow = context.watch<AuthFlowProvider>();
    final frontDone = flow.idFrontPath != null;
    final backDone = flow.idBackPath != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 8, 32, 8),
                      child: AuthBackButton(),
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
                                  text: 'driver\'s license',
                                  style: TextStyle(color: AppColors.lime),
                                ),
                              ],
                            ),
                            style: AppTextStyles.displayL.copyWith(
                              color: AppColors.textOnDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              DarkChoiceChip(
                                label: frontDone ? 'Front ✓' : 'Front',
                                selected: scan.side == IdSide.front,
                                onTap: () => scan.selectSide(IdSide.front),
                              ),
                              const SizedBox(width: 8),
                              DarkChoiceChip(
                                label: backDone ? 'Back ✓' : 'Back',
                                selected: scan.side == IdSide.back,
                                onTap: () => scan.selectSide(IdSide.back),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Center(
                      child: Wrap(
                        spacing: 8,
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GalleryThumbnailButton(
                            onPressed: () =>
                                _capture(context, fromCamera: false),
                          ),
                          ShutterButton(
                            onPressed: () =>
                                _capture(context, fromCamera: true),
                          ),
                          // Balances the gallery button.
                          const SizedBox(width: 72, height: 56),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 40),
                  ],
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
