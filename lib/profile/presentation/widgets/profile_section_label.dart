import 'package:flutter/material.dart';

import '../../core/constants/profile_styles.dart';

/// Uppercase section title ("HOW YOU USE KIDPOOL", "YOUR KIDS", …) with an
/// optional trailing action ("Manage").
class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text.toUpperCase(), style: ProfileStyles.section),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
