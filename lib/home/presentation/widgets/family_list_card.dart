import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/home_text_styles.dart';
import '../../domain/entities/family.dart';
import 'person_avatar.dart';
import 'select_box.dart';

/// F14 family row: photo, parent name and "child · place · distance".
/// In select mode a [SelectBox] leads the row.
class FamilyListCard extends StatelessWidget {
  const FamilyListCard({
    super.key,
    required this.family,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
  });

  final Family family;
  final VoidCallback onTap;
  final bool selectable;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusRow);
    return Semantics(
      checked: selectable ? selected : null,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (selectable) ...[
                  SelectBox(checked: selected),
                  const SizedBox(width: 8),
                ],
                PersonAvatar(family.avatarAsset, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(family.parentName, style: HomeTextStyles.familyName),
                      const SizedBox(height: 2),
                      Text(
                        family.detailLabel,
                        style: HomeTextStyles.bodyM,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
