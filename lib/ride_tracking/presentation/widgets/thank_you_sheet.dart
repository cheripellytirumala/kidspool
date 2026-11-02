import 'package:flutter/material.dart';

import '../../../common/presentation/theme/app_colors.dart';
import '../../../common/presentation/theme/app_text_styles.dart';
import '../../../common/presentation/widgets/app_button.dart';

/// "Say thank you": pick 1–5 stars. Returns the rating, or null.
Future<int?> showThankYouSheet(BuildContext context, {required String name}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ThankYouSheet(name: name),
  );
}

class _ThankYouSheet extends StatefulWidget {
  const _ThankYouSheet({required this.name});

  final String name;

  @override
  State<_ThankYouSheet> createState() => _ThankYouSheetState();
}

class _ThankYouSheetState extends State<_ThankYouSheet> {
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Say thanks to ${widget.name}',
              style: AppTextStyles.headingH3,
            ),
            const SizedBox(height: 6),
            Text('How was the ride?', style: AppTextStyles.body),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    iconSize: 40,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: i <= _rating
                          ? AppColors.ink
                          : AppColors.borderField,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Send thanks',
              onPressed: () => Navigator.pop(context, _rating),
            ),
          ],
        ),
      ),
    );
  }
}
