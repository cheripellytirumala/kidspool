import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import '../../domain/entities/child.dart';
import 'kid_avatar.dart';

/// Collapsed kid card ("Kid · Emma" on F06/F07): photo, name, age · grade
/// and an Edit pill. The whole card opens the editor.
class KidSummaryCard extends StatelessWidget {
  const KidSummaryCard({super.key, required this.child, required this.onEdit});

  final Child child;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 14,
            children: [
              KidAvatar(child: child, size: 60),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      child.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingH3,
                    ),
                    if (child.summary.isNotEmpty)
                      Text(
                        child.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KidsTextStyles.bodyM,
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Edit ${child.firstName}',
                excludeSemantics: true,
                child: Material(
                  color: AppColors.screen,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: onEdit,
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          const AppIcon(KidsAssets.pencil, size: 16),
                          Text('Edit', style: KidsTextStyles.labelS),
                        ],
                      ),
                    ),
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
