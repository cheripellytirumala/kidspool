import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../core/constants/ask_ride_assets.dart';
import 'ask_ride_common.dart';
import 'ask_ride_text_styles.dart';

/// "Often · Just once" / "Often · Custom" card: calendar disc, title,
/// summary and a 32px radio.
class FrequencyOptionCard extends StatelessWidget {
  const FrequencyOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(kOptionCardRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kOptionCardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconDisc(
                  size: 52,
                  child: IconDisc(
                    // Icon/calendar draws its 18×19 glyph inset in a 24 box.
                    child: SizedBox.square(
                      dimension: 16,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(2, 1.33, 2, 2),
                        child: SvgPicture.asset(AskRideAssets.calendarSolid),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.headingH3),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AskRideTextStyles.optionSubtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _Radio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SvgPicture.asset(AskRideAssets.radioOn, width: 32, height: 32);
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.screen,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderField, width: 2.5),
      ),
    );
  }
}
