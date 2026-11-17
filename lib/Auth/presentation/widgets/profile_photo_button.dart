import 'dart:io';

import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_assets.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_icon.dart';

/// "Photo" on About you: a rounded box with a camera icon, "Add photo" and
/// "Optional", or the chosen photo. It fills the size its parent gives it,
/// so it lines up with the name fields beside it.
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
      label: path == null
          ? 'Add a photo of yourself, optional'
          : 'Change your photo',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusField),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: path == null
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(AppAssets.iconCamera),
                      const SizedBox(height: 6),
                      Text(
                        'Add photo',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Optional',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                )
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
        ),
      ),
    );
  }
}
