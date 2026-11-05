import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text_styles.dart';

/// Standard screen layout from the Figma frames: 20px side padding, Display/L
/// headline, optional subtitle, 14px gap between blocks, and an optional
/// bottom action pinned above the safe area.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.bottom,
    this.scrollable = true,
    this.gap = AppDimens.sectionGap,
    this.backgroundColor = AppColors.screen,
    this.showBack = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.screenPadding,
      8,
      AppDimens.screenPadding,
      28,
    ),
  });

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  /// Usually an [AppButton]; stays visible above the keyboard.
  final Widget? bottom;
  final bool scrollable;
  final double gap;
  final Color backgroundColor;
  final bool showBack;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = backgroundColor.computeLuminance() < 0.5;

    final content = <Widget>[
      if (showBack)
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 26),
            color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
      if (title != null || subtitle != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title!,
                style: AppTextStyles.displayL.copyWith(
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: AppTextStyles.body),
            ],
          ],
        ),
      ...children,
    ];

    final body = scrollable
        ? ListView.separated(
            padding: padding.copyWith(
              bottom: bottom == null ? padding.bottom : 16,
            ),
            itemCount: content.length,
            separatorBuilder: (_, _) => SizedBox(height: gap),
            itemBuilder: (_, i) => content[i],
          )
        : Padding(
            padding: padding.copyWith(
              bottom: bottom == null ? padding.bottom : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < content.length; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  content[i],
                ],
              ],
            ),
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: body),
              if (bottom != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    padding.left,
                    0,
                    padding.right,
                    padding.bottom,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
