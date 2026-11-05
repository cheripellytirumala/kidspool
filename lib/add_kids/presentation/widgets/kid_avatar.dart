import 'dart:io';

import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../domain/entities/child.dart';

/// Round kid photo (signed URL, local file or asset); falls back to
/// initials when there is no photo or it fails to load.
class KidAvatar extends StatelessWidget {
  const KidAvatar({super.key, required this.child, required this.size});

  final Child child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = child.photo;
    final initials = ColoredBox(
      color: AppColors.surfaceStrong,
      child: Center(
        child: Text(
          child.initials,
          style: AppTextStyles.label.copyWith(fontSize: size * 0.36, height: 1),
        ),
      ),
    );
    Widget fallback(BuildContext _, Object _, StackTrace? _) => initials;

    final Widget image;
    if (photo == null) {
      image = initials;
    } else if (photo.startsWith('http')) {
      image = Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: child.firstName,
        errorBuilder: fallback,
      );
    } else if (photo.startsWith('assets/')) {
      image = Image.asset(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: child.firstName,
        errorBuilder: fallback,
      );
    } else {
      image = Image.file(
        File(photo),
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: child.firstName,
        errorBuilder: fallback,
      );
    }

    return SizedBox.square(
      dimension: size,
      child: ClipOval(child: image),
    );
  }
}
