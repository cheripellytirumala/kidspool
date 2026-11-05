import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../error/exceptions.dart';

/// Takes or picks photos sized for the backend: JPEG, at most 1 MB
/// (the limit of the `identity-documents` and `kid-photos` buckets).
class PhotoPicker {
  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int maxBytes = 1024 * 1024;

  /// Returns the local file path, or `null` when the user cancels.
  /// Throws [DeviceException] when the camera/gallery is unavailable or the
  /// photo is still too large.
  Future<String?> pick({
    required bool fromCamera,
    bool frontCamera = false,
  }) async {
    // Try a good quality first, then shrink if the file is over 1 MB.
    const attempts = [(1600.0, 85), (1200.0, 70), (900.0, 60)];
    XFile? file;
    try {
      for (final (size, quality) in attempts) {
        file = await _picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          preferredCameraDevice: frontCamera
              ? CameraDevice.front
              : CameraDevice.rear,
          maxWidth: size,
          maxHeight: size,
          imageQuality: quality,
          requestFullMetadata: false,
        );
        if (file == null) return null;
        if (await File(file.path).length() <= maxBytes) return file.path;
        // Gallery: re-picking would ask the user again, so stop here.
        if (!fromCamera) break;
      }
    } on Exception catch (_) {
      throw DeviceException(
        fromCamera
            ? 'We can’t open the camera. Check camera access in Settings.'
            : 'We can’t open your photos. Check photo access in Settings.',
      );
    }
    throw const DeviceException(
      'That photo is too large (max 1 MB). Please try another one.',
    );
  }
}
