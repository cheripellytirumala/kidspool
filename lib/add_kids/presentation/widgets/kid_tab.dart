import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/child.dart';
import 'icon_disc.dart';
import 'kid_avatar.dart';

/// "Kid tab" pill on F08/F10/F11: ink when selected, surface otherwise,
/// with an optional done check once the kid has places.
class KidTab extends StatelessWidget {
  const KidTab({
    super.key,
    required this.child,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.done = false,
  });

  final Child child;
  final String subtitle;
  final bool selected;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            child: Row(
              spacing: 10,
              children: [
                KidAvatar(child: child, size: 40),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KidsTextStyles.labelL.copyWith(
                          color: selected
                              ? AppColors.textOnDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KidsTextStyles.captionM.copyWith(
                          color: selected
                              ? KidsColors.textOnDarkMuted
                              : KidsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (done)
                  selected
                      ? const IconDisc(
                          asset: KidsAssets.check,
                          size: 22,
                          iconSize: 11,
                          color: AppColors.lime,
                        )
                      : const IconDisc(
                          asset: KidsAssets.check11,
                          size: 22,
                          iconSize: 11,
                          color: AppColors.ink,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
