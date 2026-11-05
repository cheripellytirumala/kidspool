import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import 'kids_icon_button.dart';

/// Page layout shared by the Kids frames: optional top bar (56px back button
/// + trailing badge), Display/L header with an 8px inset, a scrollable body
/// and a primary action pinned 32px above the bottom edge.
class KidsScaffold extends StatelessWidget {
  const KidsScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.titleGap = 6,
    required this.children,
    this.gap = 10,
    this.bottom,
    this.showBack = true,
    this.trailing,
    this.topPadding = 12,
    this.backgroundColor = AppColors.screen,
    this.above = const [],
  });

  final String? title;
  final String? subtitle;
  final double titleGap;
  final List<Widget> children;
  final double gap;
  final Widget? bottom;
  final bool showBack;
  final Widget? trailing;
  final double topPadding;
  final Color backgroundColor;

  /// Widgets placed above the header (e.g. the F12 check disc).
  final List<Widget> above;

  bool get _isDark => backgroundColor.computeLuminance() < 0.5;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final hasBack = showBack && canPop;
    final bottomInset = math.max(
      32.0,
      MediaQuery.viewPaddingOf(context).bottom,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasBack || trailing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (hasBack)
                        KidsIconButton(
                          asset: KidsAssets.arrowLeft,
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                        )
                      else
                        const SizedBox(height: 56),
                      ?trailing,
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: gap,
                    children: [
                      ...above,
                      if (title != null || subtitle != null) _header(),
                      ...children,
                    ],
                  ),
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title!,
                style: AppTextStyles.displayL.copyWith(
                  color: _isDark ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ),
          if (subtitle != null) ...[
            SizedBox(height: titleGap),
            Text(
              subtitle!,
              style: _isDark
                  ? KidsTextStyles.bodyM.copyWith(
                      color: AppColors.textOnDarkMuted,
                    )
                  : KidsTextStyles.bodyM,
            ),
          ],
        ],
      ),
    );
  }
}
