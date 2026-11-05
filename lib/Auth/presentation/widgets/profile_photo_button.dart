import 'dart:io';

import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// "Photo" — 84px rounded square with a camera icon, or the chosen photo.
class ProfilePhotoButton extends StatelessWidget {
  const ProfilePhotoButton({super.key, required this.onTap, this.imagePath});

  final VoidCallback onTap;

  /// Local file of the chosen photo.
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return Semantics(
      button: true,
      label: path == null ? 'Add a photo of yourself' : 'Change your photo',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 84,
            child: path == null
                ? const Center(child: AppIcon(AppAssets.iconCamera))
                : Image.file(File(path), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
