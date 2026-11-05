import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../core/constants/ask_ride_assets.dart';
import 'ask_ride_text_styles.dart';

/// Scrim colour of the Figma sheets: #0A0A0A at 55%.
const Color kAskRideScrim = Color(0x8C0A0A0A);

/// Opens [child] (usually an [AskRideSheet]) as the white 36px-radius
/// bottom sheet used across the G1 flow and returns what it pops with.
Future<T?> showAskRideSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.screen,
    barrierColor: kAskRideScrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
    ),
    builder: (_) => child,
  );
}

/// Sheet layout: grab handle, title with close button, scrollable body and
/// a pinned [footer].
class AskRideSheet extends StatelessWidget {
  const AskRideSheet({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: _gap),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: AskRideTextStyles.headingH2),
                      ),
                    ),
                    const _CloseButton(),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, _gap, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: _gap),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              _gap,
              20,
              (bottomInset > 0 ? 12 : 30) + safeBottom,
            ),
            child: footer ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pop(),
          child: SizedBox.square(
            dimension: 36,
            child: Center(
              child: SvgPicture.asset(
                AskRideAssets.close,
                width: 16,
                height: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
