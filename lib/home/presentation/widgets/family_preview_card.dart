import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../core/constants/home_text_styles.dart';
import '../../domain/entities/family.dart';
import 'person_avatar.dart';

/// Compact family tile on the Home dashboard ("Family · Jen P.").
class FamilyPreviewCard extends StatelessWidget {
  const FamilyPreviewCard({
    super.key,
    required this.family,
    required this.onTap,
  });

  final Family family;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimens.radiusRow);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              PersonAvatar.initials(family.initials),
              const SizedBox(height: 6),
              Text(
                family.parentName,
                style: HomeTextStyles.labelL,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // The design lets this label run into the card padding; scale
              // it down instead of truncating on narrow tiles.
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    family.compactLabel,
                    style: HomeTextStyles.captionS,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
