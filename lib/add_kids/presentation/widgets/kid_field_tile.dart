import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/widgets/app_icon.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import 'icon_disc.dart';

/// White field row of the F06 form ("Dropdown · Name/Age/Grade/Medical"):
/// 40px icon disc, 12px label and a 16px value. Editable when a
/// [controller] is given, otherwise a tappable picker with a chevron.
class KidFieldTile extends StatelessWidget {
  const KidFieldTile({
    super.key,
    required this.icon,
    required this.label,
    this.controller,
    this.value,
    this.hint,
    this.onTap,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
  });

  final String icon;
  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? hint;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  bool get _isPicker => controller == null;

  @override
  Widget build(BuildContext context) {
    final hintStyle = KidsTextStyles.labelL.copyWith(
      color: KidsColors.textSecondary,
    );

    final Widget valueWidget = _isPicker
        ? Text(
            value ?? hint ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: value == null ? hintStyle : KidsTextStyles.labelL,
          )
        : TextField(
            focusNode: focusNode,
            controller: controller,
            style: KidsTextStyles.labelL,
            textCapitalization: textCapitalization,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: hintStyle,
            ),
          );

    return Material(
      color: AppColors.screen,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            spacing: 3,
            children: [
              IconDisc(
                asset: icon,
                size: 40,
                iconSize: 20,
                color: AppColors.screen,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 1,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KidsTextStyles.captionM,
                    ),
                    valueWidget,
                  ],
                ),
              ),
              if (_isPicker)
                const RotatedBox(
                  quarterTurns: 1,
                  child: AppIcon(KidsAssets.chevronRight, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
