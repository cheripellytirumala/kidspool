import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../../common/presentation/widgets/app_snack.dart';
import '../providers/auth_flow_provider.dart';
import '../providers/review_status_provider.dart';

/// "We're reviewing your ID" — shown while `profiles.onboarding_status` is
/// `pending_review` (or `rejected`). Refreshes `get_my_status` on open and
/// on "Check again"; continues to Add a child once approved.
class ReviewPendingScreen extends StatelessWidget {
  const ReviewPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewStatusProvider>(
      create: (_) => sl<ReviewStatusProvider>(),
      child: const _ReviewPendingBody(),
    );
  }
}

class _ReviewPendingBody extends StatefulWidget {
  const _ReviewPendingBody();

  @override
  State<_ReviewPendingBody> createState() => _ReviewPendingBodyState();
}

class _ReviewPendingBodyState extends State<_ReviewPendingBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh({bool manual = false}) async {
    final review = context.read<ReviewStatusProvider>();
    final next = await review.refresh();
    if (!mounted) return;
    if (next != null) {
      Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
    } else if (review.errorMessage != null) {
      showAppSnack(context, review.errorMessage!);
    } else if (manual && !review.isRejected) {
      showAppSnack(context, 'Still in review. We’ll be quick!');
    }
  }

  void _retake() {
    sl<AuthFlowProvider>().clearIdPhotos();
    Navigator.pushNamed(context, AppRoutes.scanPhotoId);
  }

  @override
  Widget build(BuildContext context) {
    final review = context.watch<ReviewStatusProvider>();
    final rejected = review.isRejected;
    final name = review.firstName;

    return Scaffold(
      backgroundColor: AppColors.screen,
      body: AppLoadingOverlay(
        isLoading: review.isLoading,
        message: 'Checking your status…',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rejected ? AppColors.surface : AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected
                        ? Icons.error_outline
                        : Icons.hourglass_top_rounded,
                    size: 40,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  rejected
                      ? 'We couldn’t verify your ID'
                      : 'Thanks${name.isEmpty ? '' : ', $name'}! '
                            'We’re reviewing your ID',
                  style: AppTextStyles.displayL,
                ),
                const SizedBox(height: 12),
                Text(
                  rejected
                      ? (review.rejectionReason?.isNotEmpty ?? false)
                            ? review.rejectionReason!
                            : 'Please retake clear photos of your license.'
                      : 'To keep kids safe, a person checks every parent’s ID. '
                            'This usually takes a few hours. You can close the '
                            'app — we’ll pick up right here.',
                  style: AppTextStyles.bodyL.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (rejected) ...[
                  AppButton(label: 'Retake photos', onPressed: _retake),
                  const SizedBox(height: 12),
                ],
                AppButton(
                  label: 'Check again',
                  isLoading: review.isLoading,
                  onPressed: () => _refresh(manual: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
