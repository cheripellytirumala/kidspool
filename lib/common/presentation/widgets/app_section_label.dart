import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Uppercase section label, e.g. "I WANT TO".
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text.toUpperCase(), style: AppTextStyles.caption),
    );
  }
}
