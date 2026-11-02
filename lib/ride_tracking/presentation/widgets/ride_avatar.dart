import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Figma "Avatar": a photo from the API, or initials on lime.
class RideAvatar extends StatelessWidget {
  const RideAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 44,
    this.borderColor,
  });

  final String initials;
  final String? photoUrl;
  final double size;

  /// 2px ring (stacked kid photos on the trip summary).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.lime,
      child: Center(
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnLime,
          ),
        ),
      ),
    );
    final url = photoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Kid photos overlapping by a third (Trip summary "Photo · EM").
class RideKidAvatars extends StatelessWidget {
  const RideKidAvatars({
    super.key,
    required this.kids,
    this.size = 40,
    this.ring = AppColors.surface,
  });

  /// (initial, photoUrl) per kid.
  final List<(String, String?)> kids;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final shown = kids.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 2 / 3;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: RideAvatar(
                initials: shown[i].$1,
                photoUrl: shown[i].$2,
                size: size,
                borderColor: ring,
              ),
            ),
        ],
      ),
    );
  }
}
