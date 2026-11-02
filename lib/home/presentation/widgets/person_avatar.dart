import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';

/// Round photo of a person (Figma "Photo · XX").
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.asset, {super.key, this.size = 48});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox.square(
          dimension: size,
          child: const ColoredBox(color: AppColors.surfaceStrong),
        ),
      ),
    );
  }
}
