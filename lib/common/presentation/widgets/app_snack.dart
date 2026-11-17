import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows [message] in the app's floating ink snack bar.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
    );
}

/// Bottom sheet asking whether to use the camera or the photo library,
/// with a title and a close (X) button. Returns `true` for camera, `false` for
/// library, `null` when cancelled or dismissed.
Future<bool?> showPhotoSourceSheet(
  BuildContext context, {
  String title = 'Add a photo',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.screen,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    ),
  );
}
