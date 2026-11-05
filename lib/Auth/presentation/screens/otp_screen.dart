import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/auth_assets.dart';
import '../../core/constants/auth_styles.dart';
import '../providers/auth_flow_provider.dart';
import '../providers/otp_provider.dart';
import '../widgets/otp_code_input.dart';
import '../widgets/phone_field_preview.dart';
import '../widgets/phone_number_formatter.dart';
import '../widgets/phone_number_view.dart';

/// S03a · Code (auto-filled) — Figma node 1018:7889.
///
/// A bottom sheet over the dimmed phone-number screen. The SMS code is
/// auto-filled after a short delay (simulated); tapping the scrim goes back
/// to edit the number.
class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthFlowProvider>.value(
          value: sl<AuthFlowProvider>(),
        ),
        ChangeNotifierProvider<OtpProvider>(
          create: (_) => sl<OtpProvider>()..start(),
        ),
      ],
      child: const _OtpBody(),
    );
  }
}

class _OtpBody extends StatelessWidget {
  const _OtpBody();

  @override
  Widget build(BuildContext context) {
    final digits = context.select<AuthFlowProvider, String>(
      (flow) => flow.phoneDigits,
    );
    final isVerifying = context.select<OtpProvider, bool>(
      (otp) => otp.isVerifying,
    );
    final isSending = context.select<OtpProvider, bool>((otp) => otp.isSending);

    return Scaffold(
      backgroundColor: AppColors.screen,
      resizeToAvoidBottomInset: false,
      body: AppLoadingOverlay(
        isLoading: isVerifying || isSending,
        message: isVerifying ? 'Verifying…' : 'Sending code…',
        child: Stack(
          children: [
            // S03 underneath, frozen.
            IgnorePointer(
              child: PhoneNumberView(
                onSendOtp: () {},
                field: PhoneFieldPreview(
                  value: UsPhoneNumberFormatter.format(digits),
                ),
              ),
            ),
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Edit number',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const ColoredBox(color: AuthColors.scrim),
                ),
              ),
            ),
            const Align(alignment: Alignment.bottomCenter, child: _CodeSheet()),
          ],
        ),
      ),
    );
  }
}

class _CodeSheet extends StatelessWidget {
  const _CodeSheet();

  Future<void> _verify(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final next = await context.read<OtpProvider>().verify();
    if (next == null || !context.mounted) return;
    // Signed in: the phone/code screens are done. New users continue the
    // sign-up flow; returning users jump to where they left off.
    Navigator.pushNamedAndRemoveUntil(context, next, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final otp = context.watch<OtpProvider>();
    final phone = context.select<AuthFlowProvider, String>(
      (flow) => flow.nationalPhone,
    );
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom
        : media.padding.bottom;

    return Material(
      color: AppColors.screen,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 12, 22, 30 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.surfaceStrong,
                borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Enter the code',
              textAlign: TextAlign.center,
              style: AuthTextStyles.headingH2,
            ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Sent to $phone',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            OtpCodeInput(
              code: otp.code,
              length: OtpProvider.codeLength,
              onChanged: context.read<OtpProvider>().setCode,
            ),
            if (otp.autoFilled) ...[
              const SizedBox(height: 14),
              const _AutoFilledChip(),
            ],
            if (otp.errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                otp.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 14),
            AppButton(
              label: 'Verify',
              isLoading: otp.isVerifying,
              onPressed: otp.isComplete ? () => _verify(context) : null,
            ),
            const SizedBox(height: 14),
            _ResendCode(otp: otp),
          ],
        ),
      ),
    );
  }
}

class _AutoFilledChip extends StatelessWidget {
  const _AutoFilledChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AuthAssets.iconMessage, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Filled in from your messages ✓',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendCode extends StatelessWidget {
  const _ResendCode({required this.otp});

  final OtpProvider otp;

  @override
  Widget build(BuildContext context) {
    if (!otp.canResend) {
      return Text(
        'Resend code in ${otp.resendCountdown}',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      );
    }
    return Semantics(
      button: true,
      child: InkWell(
        onTap: otp.resend,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Resend code',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
