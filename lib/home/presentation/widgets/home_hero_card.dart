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
  });

  final String illustration;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
  }
}
