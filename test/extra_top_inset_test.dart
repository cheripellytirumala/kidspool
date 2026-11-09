import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/presentation/theme/app_dimens.dart';
import 'package:kidspool/common/presentation/widgets/extra_top_inset.dart';

void main() {
  for (final statusBar in [0.0, 24.0, 47.0, 59.0]) {
    testWidgets('SafeArea content starts ${AppDimens.extraTopInset}px lower '
        '(status bar $statusBar)', (tester) async {
      const key = Key('content');
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: EdgeInsets.only(top: statusBar, bottom: 34),
            viewPadding: EdgeInsets.only(top: statusBar, bottom: 34),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: ExtraTopInset(
              child: SafeArea(child: SizedBox(key: key, height: 10)),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(key)).dy,
        statusBar + AppDimens.extraTopInset,
      );
      // Bottom inset untouched.
      final ctx = tester.element(find.byType(SafeArea));
      expect(MediaQuery.paddingOf(ctx).bottom, 34);
    });
  }
}
