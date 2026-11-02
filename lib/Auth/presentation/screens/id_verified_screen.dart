import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../../domain/entities/scanned_id.dart';
import '../providers/auth_flow_provider.dart';
import '../widgets/auth_back_button.dart';
import '../widgets/id_summary_card.dart';

/// V3 · ID verified — Figma nodes 1018:8286 (photo uploaded from the
/// gallery) and 1018:12726 (license scanned with the camera).
///
/// On open, the license is read on the device with Google ML Kit (PDF417
/// barcode on the back, text recognition on the front) so the parent can
/// check the details, fix a name mismatch, and is stopped early when the
/// license has expired. The photos are then sent for human review.
class IdVerifiedScreen extends StatelessWidget {
  const IdVerifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthFlowProvider>.value(
      value: sl<AuthFlowProvider>(),
      child: const _IdVerifiedBody(),
    );
  }
}

class _IdVerifiedBody extends StatefulWidget {
  const _IdVerifiedBody();

  @override
  State<_IdVerifiedBody> createState() => _IdVerifiedBodyState();
}

class _IdVerifiedBodyState extends State<_IdVerifiedBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthFlowProvider>().readLicense();
    });
  }

  Future<void> _confirm(BuildContext context) async {
    final error = await context.read<AuthFlowProvider>().submitIdentity();
    if (!context.mounted) return;
    if (error != null) return showAppSnack(context, error);
    // Sent for review: carry on to Add a child while the team checks the
    // ID in the background; don't let the user go back into sign-up.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.addChild,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AuthFlowProvider>();
    final id = flow.scannedId;
    final firstName = flow.firstName.trim();
    final uploaded = id?.source == IdSource.gallery;

    final title = uploaded
        ? 'Please check your license${firstName.isEmpty ? '' : ', $firstName'}'
        : firstName.isEmpty
        ? 'Is this you?'
        : 'Is this you, $firstName?';
    final subtitle = uploaded
        ? 'Please check the photos are sharp and your name matches your '
              'driver’s license. We’ll review them shortly.'
        : 'Please check the photos are sharp and your name matches your '
              'driver’s license.';

    return Scaffold(
      backgroundColor: AppColors.screen,
      body: AppLoadingOverlay(
        isLoading: flow.isSubmittingId || flow.isReadingLicense,
        message: flow.isSubmittingId ? 'Sending…' : 'Reading your license…',
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AuthBackButton(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppTextStyles.displayL),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: AppTextStyles.bodyL.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (id != null) ...[
                        IdSummaryCard(
                          id: id,
                          license: flow.license,
                          isReading: flow.isReadingLicense,
                        ),
                        if (flow.licenseChecked) ...[
                          const SizedBox(height: 12),
                          _LicenseNotice(flow: flow),
                        ],
                      ] else
                        Text(
                          'Take a photo of both sides of your license first.',
                          style: AppTextStyles.body,
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: AppButton(
                  label: uploaded ? 'Yes, this is my license' : 'Continue',
                  isLoading: flow.isSubmittingId,
                  onPressed:
                      flow.hasIdPhotos &&
                          !flow.isReadingLicense &&
                          !(flow.license?.isExpired ?? false)
                      ? () => _confirm(context)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result of the on-device read: expired license, name mismatch, or a hint
/// when the license couldn't be read automatically.
class _LicenseNotice extends StatelessWidget {
  const _LicenseNotice({required this.flow});

  final AuthFlowProvider flow;

  @override
  Widget build(BuildContext context) {
    final license = flow.license;

    if (license == null) {
      return const _Notice(
        text:
            'We couldn’t read your license automatically. That’s okay — '
            'just make sure the photos are sharp, with no glare.',
      );
    }
    if (license.isExpired) {
      return _Notice(
        error: true,
        text:
            'This license looks expired. Please retake the photos with a '
            'valid license.',
        action: 'Retake photos',
        onAction: () {
          flow.clearIdPhotos();
          Navigator.of(context).pop();
        },
      );
    }
    if (flow.licenseNameMismatch) {
      return _Notice(
        text:
            'Your license says “${license.fullName}”. The name you send '
            'must match your license.',
        action: 'Use name from license',
        onAction: flow.useLicenseName,
      );
    }
    return const SizedBox.shrink();
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    this.error = false,
    this.action,
    this.onAction,
  });

  final String text;
  final bool error;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFFEBEE) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: error ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.ink,
              ),
              child: Text(
                action!,
                style: AppTextStyles.label.copyWith(
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
