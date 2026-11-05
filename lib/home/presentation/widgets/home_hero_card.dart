import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/home_text_styles.dart';

/// Lime-soft "Hero" card: 150px illustration, title and optional subtitle.
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.illustration,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final String illustration;
  final String title;
  final String? subtitle;

  /// Opens the next ride; `null` keeps the card static (empty states).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusMap),
      child: ColoredBox(
        color: AppColors.limeTint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              illustration,
              height: 150,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HomeTextStyles.heroTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: HomeTextStyles.bodyM),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final tap = onTap;
    if (tap == null) return card;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: card,
      ),
    );
  }
}
