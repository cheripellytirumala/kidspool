import 'package:flutter/widgets.dart';

import '../theme/app_dimens.dart';

/// Adds [AppDimens.extraTopInset] to the top safe-area inset for the whole
/// app, so every `SafeArea` (and anything reading `MediaQuery.padding.top`)
/// starts a little lower under the status bar / notch / Dynamic Island on
/// both iOS and Android. Bottom sheets drop the top inset themselves, so
/// they're unaffected.
class ExtraTopInset extends StatelessWidget {
  const ExtraTopInset({super.key, required this.child, this.extra});

  final Widget child;

  /// Overrides [AppDimens.extraTopInset] (tests).
  final double? extra;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final add = extra ?? AppDimens.extraTopInset;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: media.padding.top + add),
        viewPadding: media.viewPadding.copyWith(
          top: media.viewPadding.top + add,
        ),
      ),
      child: child,
    );
  }
}
