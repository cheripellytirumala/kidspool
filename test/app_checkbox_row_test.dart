import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidspool/common/presentation/widgets/app_checkbox_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('underline: the whole label is underlined and toggles', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      host(
        AppCheckboxRow(
          value: false,
          label: 'I’m a parent or legal guardian, 18 or older',
          underline: true,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    final text = tester.widget<Text>(find.textContaining('legal guardian'));
    expect(text.style?.decoration, TextDecoration.underline);
    await tester.tap(find.textContaining('legal guardian'));
    expect(changed, isTrue);
  });

  testWidgets('links: tapping a link runs it instead of toggling', (
    tester,
  ) async {
    var opened = <String>[];
    var toggles = 0;
    await tester.pumpWidget(
      host(
        AppCheckboxRow(
          value: false,
          label: 'I agree to the Terms and Privacy Policy',
          links: {
            'Terms': () => opened.add('terms'),
            'Privacy Policy': () => opened.add('privacy'),
          },
          onChanged: (_) => toggles++,
        ),
      ),
    );
    final rich = find.byType(RichText).last;
    // Tap inside "Terms" and "Privacy Policy" spans.
    await tester.tapOnText(find.textRange.ofSubstring('Terms'));
    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    expect(opened, ['terms', 'privacy']);
    expect(toggles, 0);
    // The box itself still toggles.
    await tester.tapAt(tester.getTopLeft(rich) - const Offset(20, -8));
    expect(toggles, 1);
  });
}
