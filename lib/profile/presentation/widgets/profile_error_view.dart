import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';

/// Shown when the profile could not be loaded at all.
class ProfileErrorView extends StatelessWidget {
  const ProfileErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Text(
            'We couldn’t load your profile',
            textAlign: TextAlign.center,
            style: AppTextStyles.headingH3,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
          const SizedBox(height: 20),
          AppButton(label: 'Try again', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Inline error for one section (kids, addresses) with a retry link.
class ProfileSectionError extends StatelessWidget {
  const ProfileSectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message, style: AppTextStyles.body)),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: AppTextStyles.label),
        ),
      ],
    );
  }
}
