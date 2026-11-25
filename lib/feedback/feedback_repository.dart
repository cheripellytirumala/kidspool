import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:fpdart/fpdart.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../common/core/error/error_handler.dart';
import '../common/core/error/exceptions.dart';
import '../common/core/error/failures.dart';
import '../common/core/network/api_client.dart';

/// What the feedback is about. `code` is what the backend stores.
enum FeedbackKind {
  problem('problem', 'Report a problem'),
  idea('idea', 'Suggest an improvement'),
  praise('praise', 'Something I like'),
  other('other', 'Something else');

  const FeedbackKind(this.code, this.label);
  final String code;
  final String label;
}

/// Part of the app the feedback is about (optional).
enum FeedbackArea {
  signUp('sign_up', 'Sign-up'),
  kids('kids', 'Members, schools & activities'),
  askRide('ask_ride', 'Asking for a ride'),
  families('families', 'Families near you'),
  messages('messages', 'Messages & groups'),
  liveRide('live_ride', 'Live ride tracking'),
  driving('driving', 'Giving rides'),
  profile('profile', 'Profile & settings'),
  other('other', 'Other');

  const FeedbackArea(this.code, this.label);
  final String code;
  final String label;
}

/// Sends feedback to `submit_app_feedback`
/// (docs/backend/2026-11-16_app_feedback.sql), with the app version and
/// platform so the team can study it.
class FeedbackRepository {
  FeedbackRepository(this._api, {Future<String> Function()? appVersion})
    : _appVersion = appVersion ?? _readVersion;

  final ApiClient _api;
  final Future<String> Function() _appVersion;

  static const String submitFeedback = 'submit_app_feedback';

  /// Edge Function that emails new feedback to the team.
  static const String notifyFeedback = 'notify-feedback';

  Future<void> _notifyTeam() async {
    try {
      await _api.invokeFunction(
        notifyFeedback,
        data: const <String, dynamic>{},
        parser: (_) {},
      );
    } catch (_) {
      // Saved anyway; the next feedback sends any missed email.
    }
  }

  static Future<String> _readVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static String get _platform => Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
      ? 'android'
      : 'other';

  /// Screenshots / photos at most.
  static const int maxAttachments = 3;

  /// Saves the feedback, then uploads [attachments] (local image paths) and
  /// emails the team. Right(true) when everything was saved; Right(false)
  /// when the feedback was saved but the attachments couldn't be uploaded.
  Future<Either<Failure, bool>> send({
    required FeedbackKind kind,
    required String message,
    FeedbackArea? area,
    int? rating,
    List<String> attachments = const [],
  }) => ErrorHandler.guard(tag: 'Feedback.send', () async {
    String? version;
    try {
      version = await _appVersion();
    } catch (_) {
      version = null;
    }
    final String? feedbackId;
    try {
      feedbackId = await _api.rpc(
        submitFeedback,
        params: {
          'kind': kind.code,
          'message': message.trim(),
          'rating': ?rating,
          'area': ?area?.code,
          'app_version': ?version,
          'platform': _platform,
          'os_version': Platform.operatingSystemVersion,
        },
        parser: (data) =>
            data is Map<String, dynamic> ? data['feedbackId'] as String? : null,
      );
    } on UnauthorizedException {
      rethrow;
    } on ServerException catch (e) {
      final code = (e.data['message'] ?? e.code)?.toString();
      final missing =
          e.code == 'PGRST202' ||
          e.data['code'] == 'PGRST202' ||
          (e.statusCode == 404 && e.code == null);
      throw ServerException(
        missing
            ? 'Feedback isn’t available yet. Please email '
                  'bowapps@nfcsolutionsusa.com.'
            : switch (code) {
                'too_much_feedback' =>
                  'Thanks! You’ve sent a lot of feedback. Try again later.',
                'message_too_short' => 'Tell us a little more.',
                _ => e.message,
              },
        e.statusCode,
        e.code,
        e.data,
      );
    }
    final files = attachments.take(maxAttachments).toList();
    if (files.isEmpty || feedbackId == null) {
      // Email it to the team (best effort, in the background).
      unawaited(_notifyTeam());
      return files.isEmpty;
    }
    // Upload the screenshots; the same call emails the team.
    try {
      await _api.invokeFunction(
        notifyFeedback,
        data: FormData.fromMap({
          'feedbackId': feedbackId,
          for (final (i, path) in files.indexed)
            'file$i': await MultipartFile.fromFile(path),
        }),
        parser: (_) {},
      );
      return true;
    } on UnauthorizedException {
      rethrow;
    } catch (_) {
      // The feedback itself is saved; email it without the photos.
      unawaited(_notifyTeam());
      return false;
    }
  });
}
