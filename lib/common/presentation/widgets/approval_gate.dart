import 'package:flutter/material.dart';

import '../../core/di/injection_container.dart';
import '../../core/router/onboarding_route.dart';
import '../../domain/repositories/account_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'app_loader.dart';

/// Guards screens that need a finished sign-up (add kids, home, rides).
///
/// Checks `get_my_status` before showing [child]. Once the license has been
/// sent (in review or approved) the parent carries on. If sign-up isn't
/// finished, or the ID was rejected, it replaces the stack with the right
/// onboarding step (About you, scan ID, or retake photos).
class ApprovalGate extends StatefulWidget {
  const ApprovalGate({super.key, required this.child});

  final Widget child;

  /// Once approved, later screens skip the check. Cleared on sign-out via
  /// [resetSessionState].
  static bool _approved = false;

  static void reset() => _approved = false;

  @override
  State<ApprovalGate> createState() => _ApprovalGateState();
}

class _ApprovalGateState extends State<ApprovalGate> {
  bool _checking = !ApprovalGate._approved;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_checking) _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await sl<AccountRepository>().getMyStatus();
    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _checking = false;
        _error = failure.message;
      }),
      (status) {
        if (status.hasSubmittedId) {
          ApprovalGate._approved = true;
          setState(() => _checking = false);
          return;
        }
        // Sign-up not finished or ID rejected: send them to that step.
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(OnboardingRoute.of(status), (_) => false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && _error == null) return widget.child;
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          child: Center(
            child: _error == null
                ? const AppLoader(semanticsLabel: 'Checking your account')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyL,
                      ),
                      const SizedBox(height: 16),
                      AppButton(label: 'Try again', onPressed: _check),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
