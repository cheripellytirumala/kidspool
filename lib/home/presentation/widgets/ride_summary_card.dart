import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/home_assets.dart';
import '../../core/constants/home_text_styles.dart';
import '../../domain/entities/ride_summary.dart';
import 'person_avatar.dart';

/// "Ride summary" card at the top of F14 select mode, with an edit pencil.
class RideSummaryCard extends StatelessWidget {
  const RideSummaryCard({super.key, required this.ride, required this.onEdit});

  final RideSummary ride;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onEdit,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              PersonAvatar(ride.childAvatarAsset, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.title, style: HomeTextStyles.labelL),
                    const SizedBox(height: 1),
                    Text(ride.schedule, style: HomeTextStyles.captionM),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: 'Edit ride',
                button: true,
                child: const AppIcon(HomeAssets.iconPencil, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
