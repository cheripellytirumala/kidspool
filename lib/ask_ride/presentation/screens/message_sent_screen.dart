import '../../../common/core/router/open_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../common/core/di/injection_container.dart';
import '../../../common/core/router/app_routes.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import '../providers/ask_ride_provider.dart';
import '../widgets/ask_ride_common.dart';
import '../widgets/ask_ride_text_styles.dart';

/// F20 · Message sent to all selected parents (success).
///
/// The parent count comes from the route arguments (an `int`) or from
/// [AskRideProvider.markSent]; without either the copy stays generic.
class MessageSentScreen extends StatelessWidget {
  const MessageSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AskRideProvider>.value(
      value: sl<AskRideProvider>(),
      child: const _MessageSentView(),
    );
  }
}

class _MessageSentView extends StatelessWidget {
  const _MessageSentView();

  static const List<({String icon, String title, String subtitle})> _steps = [
    (
      icon: AskRideAssets.send,
      title: 'They get your message now',
      subtitle: 'Each parent sees it in their Requests',
    ),
    (
      icon: AskRideAssets.bell,
      title: 'You get a notification for each reply',
      subtitle: 'No need to keep the app open',
    ),
    (
      icon: AskRideAssets.message,
      title: 'Replies show in Messages',
      subtitle: 'Chat, then choose who drives',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.settingsOf(context)?.arguments;
    final count =
        (args is int ? args : null) ??
        context.select<AskRideProvider, int?>((p) => p.sentToCount);
    final title = switch (count) {
      null => 'Your message was sent to all selected parents',
      1 => 'Your message was sent to 1 parent',
      _ => 'Your message was sent to $count parents',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        // Going back would re-open the families sheet for a request that
        // was already sent.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goHome(context);
        },
        child: Scaffold(
          backgroundColor: AppColors.screen,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                const _SuccessMark(),
                const SizedBox(height: 12),
                const Center(child: _SentBadge()),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AskRideTextStyles.successTitle,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We’ll let you know as soon as someone replies.',
                  textAlign: TextAlign.center,
                  style: AskRideTextStyles.successSubtitle,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT HAPPENS NEXT',
                        style: AskRideTextStyles.sectionCaption,
                      ),
                      for (final step in _steps) ...[
                        const SizedBox(height: 12),
                        _NextStepRow(
                          icon: step.icon,
                          title: step.title,
                          subtitle: step.subtitle,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AskRideActionButton(
                  label: 'Go to Messages',
                  icon: AskRideAssets.messageButton,
                  onPressed: () => _goToMessages(context),
                ),
                const SizedBox(height: 16),
                AskRideActionButton(
                  label: 'Back to Home',
                  icon: AskRideAssets.homeOutline,
                  background: AppColors.surface,
                  onPressed: () => _goHome(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToMessages(BuildContext context) {
    context.read<AskRideProvider>().reset();
    goToMessages(Navigator.of(context));
  }

  void _goHome(BuildContext context) {
    context.read<AskRideProvider>().reset();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconDisc(
        size: 116,
        color: AppColors.limeTint,
        child: IconDisc(
          size: 84,
          color: AppColors.lime,
          child: SvgPicture.asset(
            AskRideAssets.successCheck,
            width: 42,
            height: 42,
          ),
        ),
      ),
    );
  }
}

class _SentBadge extends StatelessWidget {
  const _SentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: const ShapeDecoration(
        color: AppColors.ink,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(AskRideAssets.sendLime, width: 16, height: 16),
          const SizedBox(width: 6),
          Text('Sent!', style: AskRideTextStyles.sentBadge),
        ],
      ),
    );
  }
}

class _NextStepRow extends StatelessWidget {
  const _NextStepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconDisc(
          size: 42,
          child: SvgPicture.asset(icon, width: 21, height: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AskRideTextStyles.labelL),
              Text(subtitle, style: AskRideTextStyles.optionSubtitle),
            ],
          ),
        ),
      ],
    );
  }
}
