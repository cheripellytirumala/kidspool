import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';

/// Figma "Avatar" / "Photo · SM": round photo, or initials on lime when
/// there is no photo (or it fails to load).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    required this.initials,
    this.photoUrl,
  });

  final double size;
  final String initials;

  /// Signed `https://` URL from the API.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.lime,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: size * 0.36,
            height: 1,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnLime,
          ),
        ),
      ),
    );
    final url = photoUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: url != null && url.startsWith('http')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
