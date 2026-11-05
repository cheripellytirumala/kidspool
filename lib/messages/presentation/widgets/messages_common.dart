import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../../common/presentation/widgets/app_loader.dart';
import '../../core/constants/messages_assets.dart';
import '../../core/constants/messages_styles.dart';

/// Round avatar: photo when there is one, else initials on [background].
class MessagesAvatar extends StatelessWidget {
  const MessagesAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 48,
    this.background = AppColors.screen,
    this.border,
  });

  final String initials;
  final String? photoUrl;
  final double size;
  final Color background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initials,
        maxLines: 1,
        style: MessagesStyles.labelL.copyWith(fontSize: size * 0.36),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: photoUrl == null
          ? fallback
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// White circle with the people icon (chat avatar in F24 / F19).
class MessagesGroupAvatar extends StatelessWidget {
  const MessagesGroupAvatar({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.screen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcon(MessagesAssets.group, size: size * 33 / 48),
    );
  }
}

/// Figma "Icon Button" — surface circle with the back arrow.
class MessagesBackButton extends StatelessWidget {
  const MessagesBackButton({super.key, this.size = 56, this.onPressed});

  final double size;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: size,
            child: const Center(
              child: AppIcon(AppAssets.iconArrowLeft, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

/// `RIDE REQUESTS · 2`.
class MessagesSectionLabel extends StatelessWidget {
  const MessagesSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 4),
        child: Text(text.toUpperCase(), style: MessagesStyles.section),
      ),
    );
  }
}

/// 50px pill used inside cards ("I can help" / "Not this time").
class MessagesPillButton extends StatelessWidget {
  const MessagesPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.dark = false,
    this.background = AppColors.screen,
    this.isLoading = false,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dark;

  /// Light style fill (white on surface cards, surface on white).
  final Color background;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final enabled = onPressed != null && !isLoading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || isLoading ? 1 : 0.4,
        child: Material(
          color: dark ? AppColors.ink : background,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: isLoading
                    ? AppLoader.glyph(size: 22, color: fg)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MessagesStyles.labelL.copyWith(color: fg),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + text line on request cards (`Home → Lincoln`, `Thu · 8:30 AM`).
class MessagesIconLine extends StatelessWidget {
  const MessagesIconLine({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize = 18,
    this.style,
  });

  final String icon;
  final String text;
  final double iconSize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, size: iconSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ?? MessagesStyles.labelL,
          ),
        ),
      ],
    );
  }
}

/// Empty / error / missing-args state.
class MessagesStateView extends StatelessWidget {
  const MessagesStateView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(MessagesAssets.tabChat, size: 30),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.headingH3,
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
        if (onRetry != null) ...[
          const SizedBox(height: AppDimens.sectionGap),
          AppButton(label: 'Try again', onPressed: onRetry),
        ],
      ],
    );
  }
}

/// Full screen with a back button and a [MessagesStateView] (no route args,
/// load failed).
class MessagesStateScreen extends StatelessWidget {
  const MessagesStateScreen({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.screen,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: canPop
                          ? const MessagesBackButton()
                          : const SizedBox(height: 56),
                    ),
                    const Spacer(),
                    MessagesStateView(
                      title: title,
                      message: message,
                      onRetry: onRetry,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered loader on a white screen.
class MessagesLoadingScreen extends StatelessWidget {
  const MessagesLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.screen,
      body: Center(child: AppLoader()),
    );
  }
}

/// Confirm dialog for cancel / leave actions.
Future<bool> confirmMessagesAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.screen,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTextStyles.headingH3),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.body),
            const SizedBox(height: 20),
            AppButton(
              label: confirm,
              variant: AppButtonVariant.dark,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Keep it',
              variant: AppButtonVariant.light,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
