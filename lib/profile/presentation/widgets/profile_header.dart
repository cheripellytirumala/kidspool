import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_dimens.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/profile_assets.dart';
import '../../core/constants/profile_styles.dart';
import 'profile_avatar.dart';

/// Figma "Profile header": photo, name, phone · city, badges and
/// "Edit my details".
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.initials,
    required this.contactLine,
    required this.licenseVerified,
    required this.rideModeLabel,
    required this.onEdit,
  });

  final String name;
  final String initials;
  final String contactLine;
  final bool licenseVerified;

  /// "I get & give rides" / "I get rides only".
  final String rideModeLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Column(
        children: [
          ProfileAvatar(size: 96, initials: initials),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? 'Your profile' : name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ProfileStyles.name,
          ),
          if (contactLine.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              contactLine,
              textAlign: TextAlign.center,
              style: ProfileStyles.meta,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (licenseVerified)
                const _HeaderBadge(
                  icon: ProfileAssets.check16,
                  label: 'License verified',
                  background: AppColors.ink,
                  foreground: AppColors.textOnDark,
                ),
              _HeaderBadge(
                icon: ProfileAssets.swap16,
                label: rideModeLabel,
                background: AppColors.lime,
                foreground: AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _EditButton(onTap: onEdit),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: ProfileStyles.badge.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit my details',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.only(left: 18, right: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(ProfileAssets.pencil, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit my details', style: ProfileStyles.button),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
