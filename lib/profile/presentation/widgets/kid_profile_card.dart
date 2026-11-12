import 'package:flutter/material.dart';

import '../../../add_kids/domain/entities/child.dart';
import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/constants/profile_styles.dart';
import 'profile_avatar.dart';

/// A kid in "YOUR KIDS".
///
/// Collapsed — Figma 960:8073 "Kid · Emma": photo, age · grade, places.
/// Expanded — Figma 961:7601 "Kid · Emma": the kid's places as white rows
/// plus "Edit".
class KidProfileCard extends StatelessWidget {
  const KidProfileCard({
    super.key,
    required this.kid,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
  });

  final Child kid;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  String get _name =>
      [kid.firstName, kid.lastName].where((p) => p.trim().isNotEmpty).join(' ');

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      curve: Curves.easeOut,
      child: expanded ? _expanded() : _collapsed(),
    );
  }

  Widget _collapsed() {
    final radius = BorderRadius.circular(AppDimens.radiusRow);
    final school = kid.schoolName;
    return Semantics(
      button: true,
      expanded: false,
      child: Material(
        color: AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onToggle,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                ProfileAvatar(
                  size: 52,
                  initials: kid.initials,
                  photoUrl: kid.photo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileStyles.kidName,
                      ),
                      if (kid.summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(kid.summary, style: ProfileStyles.rowSubtitle),
                      ],
                      if (school != null && school.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const AppIcon(ProfileAssets.school14, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                school,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ProfileStyles.kidPlaces,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const AppIcon(ProfileAssets.chevronRight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expanded() {
    final school = kid.schoolName;
    final places = (school == null || school.isEmpty) ? 0 : 1;
    final subtitle = [
      if (kid.grade != null && kid.grade!.isNotEmpty) kid.grade!,
      '$places ${places == 1 ? 'place' : 'places'}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusMap),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: true,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(22),
              child: Row(
                children: [
                  ProfileAvatar(
                    size: 44,
                    initials: kid.initials,
                    photoUrl: kid.photo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileStyles.cardTitle,
                        ),
                        Text(subtitle, style: ProfileStyles.cardSubtitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const RotatedBox(
                    quarterTurns: 1,
                    child: AppIcon(ProfileAssets.chevronRight, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (school != null && school.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PlaceRow(name: school, detail: 'School'),
          ],
          const SizedBox(height: 8),
          // Schools & activities have their own Profile section.
          _InlineAction(label: 'Edit', onTap: onEdit),
        ],
      ),
    );
  }
}

/// Figma "Activity · Lincoln Elementary": white row with an icon circle
/// and an ink check.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.circular(AppDimens.radiusField),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(ProfileAssets.school16, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ProfileStyles.placeTitle),
                Text(detail, style: ProfileStyles.cardSubtitle),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(ProfileAssets.check12, size: 12),
          ),
        ],
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileStyles.placeTitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
