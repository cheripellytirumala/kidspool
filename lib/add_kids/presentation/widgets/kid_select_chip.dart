import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/child.dart';
import 'icon_disc.dart';
import 'kid_avatar.dart';

/// "WHO GOES HERE?" toggle on F10. Selected: lime-soft, 2px ink border and
/// an ink check; unselected: surface with an empty ring.
class KidSelectChip extends StatelessWidget {
  const KidSelectChip({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
  });

  final Child child;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? AppColors.ink : AppColors.surface,
        width: 2,
      ),
    );
    return Semantics(
      checked: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.limeTint : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            child: Row(
              spacing: 10,
              children: [
                KidAvatar(child: child, size: 36),
                Expanded(
                  child: Text(
                    child.firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KidsTextStyles.labelL,
                  ),
                ),
                selected
                    ? const IconDisc(
                        asset: KidsAssets.check11,
                        size: 22,
                        iconSize: 11,
                        color: AppColors.ink,
                      )
                    : Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.screen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderField,
                            width: 2,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
