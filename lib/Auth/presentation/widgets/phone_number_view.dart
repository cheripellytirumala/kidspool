import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_screen.dart';

/// Layout of "S03 · Phone number": headline, the phone [field], privacy note
/// and the "Send OTP" button pinned to the bottom. Also rendered behind the
/// S03a code sheet.
class PhoneNumberView extends StatelessWidget {
  const PhoneNumberView({
    super.key,
    required this.field,
    required this.onSendOtp,
  });

  final Widget field;

  /// Null disables the button.
  final VoidCallback? onSendOtp;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Let’s get you\nstarted',
      subtitle: 'Enter your mobile number - we’ll text you a code.',
      bottom: AppButton(label: 'Send OTP', onPressed: onSendOtp),
      children: [field, const _PrivacyNote()],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          const AppIcon(AppAssets.iconShield, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your number is never shown to other parents.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}
