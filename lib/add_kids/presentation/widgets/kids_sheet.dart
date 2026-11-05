import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/kids_assets.dart';
import '../../core/constants/kids_styles.dart';
import 'icon_disc.dart';
import 'kids_icon_button.dart';

/// Opens a Kids bottom sheet over the 55% scrim used in the designs.
Future<T?> showKidsSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: KidsColors.scrim,
    elevation: 0,
    builder: builder,
  );
}

/// Sheet surface: white, 36px top corners, drag handle, 12px gaps.
class KidsSheet extends StatelessWidget {
  const KidsSheet({super.key, required this.children, this.height});

  final List<Widget> children;

  /// Fixed height (the F09 search sheet); null wraps the content and the
  /// last child should not be [Expanded].
  final double? height;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Figma keeps 30px under the content, measured from the screen edge.
    final bottom =
        math.max(30.0, media.viewPadding.bottom) + media.viewInsets.bottom;

    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      decoration: const BoxDecoration(
        color: AppColors.screen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: const ShapeDecoration(
                color: AppColors.surfaceStrong,
                shape: StadiumBorder(),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 36px round close button of the sheets.
class KidsSheetCloseButton extends StatelessWidget {
  const KidsSheetCloseButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return KidsIconButton(
      asset: KidsAssets.close,
      size: 36,
      iconSize: 16,
      tooltip: 'Close',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Simple single-choice picker sheet (age and grade on F06).
Future<T?> showKidsOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
}) {
  return showKidsSheet<T>(context, (context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return KidsSheet(
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: KidsTextStyles.headingH2)),
            const KidsSheetCloseButton(),
          ],
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final option = options[i];
              return _OptionTile(
                label: labelOf(option),
                selected: option == selected,
                onTap: () => Navigator.of(context).pop(option),
              );
            },
          ),
        ),
      ],
    );
  });
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: selected
          ? const BorderSide(color: AppColors.ink, width: 2)
          : BorderSide.none,
    );
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.limeTint : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(child: Text(label, style: KidsTextStyles.labelL)),
                if (selected)
                  const IconDisc(
                    asset: KidsAssets.check11,
                    size: 22,
                    iconSize: 11,
                    color: AppColors.ink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
