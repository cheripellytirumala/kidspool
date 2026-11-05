import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../domain/entities/ask_ride_kid.dart';
import 'ask_ride_text_styles.dart';

/// Kid selector pill ("Kid · Emma"): 36px photo + name. Selected = ink.
class KidChip extends StatelessWidget {
  const KidChip({
    super.key,
    required this.kid,
    required this.selected,
    required this.onTap,
  });

  final AskRideKid kid;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: kid.name,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: ShapeDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          shape: const StadiumBorder(),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(child: _KidPhoto(kid: kid)),
                  const SizedBox(width: 8),
                  Text(
                    kid.name,
                    style: AskRideTextStyles.labelL.copyWith(
                      color: selected
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 36px kid photo: signed URL or asset, initials as fallback.
class _KidPhoto extends StatelessWidget {
  const _KidPhoto({required this.kid});

  final AskRideKid kid;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final photo = kid.photo;
    final initials = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      color: AppColors.surfaceStrong,
      child: Text(kid.initial, style: AskRideTextStyles.labelL),
    );
    if (photo == null) return initials;
    Widget fallback(BuildContext _, Object _, StackTrace? _) => initials;
    return photo.startsWith('http')
        ? Image.network(
            photo,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          )
        : Image.asset(
            photo,
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            errorBuilder: fallback,
          );
  }
}
