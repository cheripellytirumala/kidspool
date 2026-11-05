import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/home_text_styles.dart';

/// Round photo of a person (Figma "Photo · XX"), or their initials on the
/// lime circle used for the user's own avatar when there is no photo.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(String this.asset, {super.key, this.size = 48})
    : initials = '';

  /// No photo: [initials] on a lime circle.
  const PersonAvatar.initials(this.initials, {super.key, this.size = 48})
    : asset = null;

  final String? asset;
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null) return _initials();
    Widget fallback(_, _, _) => SizedBox.square(
      dimension: size,
      child: const ColoredBox(color: AppColors.surfaceStrong),
    );
    return ClipOval(
      child: path.startsWith('http')
          ? Image.network(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: fallback,
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: fallback,
            ),
    );
  }

  Widget _initials() {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(initials, style: HomeTextStyles.labelM, maxLines: 1),
          ),
        ),
      ),
    );
  }
}
