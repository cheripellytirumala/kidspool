import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../error/exceptions.dart';

/// Takes or picks photos sized for the backend: JPEG, at most 1 MB
/// (the limit of the `identity-documents` and `kid-photos` buckets).
class PhotoPicker {
  PhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int maxBytes = 1024 * 1024;

  /// Longest side and JPEG quality the photo is saved at. A 1280 px JPEG at
  /// 80% is typically 200–500 KB, safely under [maxBytes].
  static const double maxSide = 1280;
  static const int quality = 80;

  /// Returns the local file path, or `null` when the user cancels.
  /// Throws [DeviceException] when the camera/gallery is unavailable or the
  /// photo is still too large. Opens the camera / library only once — it is
  /// never reopened to retry at a smaller size.
  Future<String?> pick({
    required bool fromCamera,
    bool frontCamera = false,
  }) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: frontCamera
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
        requestFullMetadata: false,
      );
    } on Exception catch (_) {
      throw DeviceException(
        fromCamera
            ? 'We can’t open the camera. Check camera access in Settings.'
            : 'We can’t open your photos. Check photo access in Settings.',
      );
    }
    if (file == null) return null;
    if (await File(file.path).length() <= maxBytes) return file.path;
    throw const DeviceException(
      'That photo is too large (max 1 MB). Please try another one.',
    );
  }
}
