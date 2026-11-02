import '../../../../common/core/constants/api_constants.dart';
import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../core/constants/ride_tracking_api_constants.dart';
import '../../../domain/entities/ride_tracking.dart';
import '../../models/ride_fix.dart';
import '../../models/ride_tracking_model.dart';
import 'ride_tracking_error_messages.dart';

/// The live trip, both sides. Throws only `AppException` subtypes.
///
/// Ride Partner — `start_ride` (from 30 min before pickup), then
/// `update_ride_location` every few seconds, `mark_picked_up`, and
/// `complete_ride` at school.
///
/// Requesting parent — `get_ride_tracking`, polled while the screen shows.
abstract interface class RideTrackingRemoteDataSource {
  Future<RideTracking> getTracking(String requestId, {bool includePath});

  Future<void> startRide(String requestId, RideFix? at);

  /// Returns the miles driven since pickup.
  Future<double?> updateLocation(String requestId, RideFix at);

  Future<void> markPickedUp(String requestId, RideFix? at);

  Future<RideCompletion> completeRide(String requestId, RideFix? at);

  Future<void> triggerSos(String requestId, RideFix? at);

  Future<void> rateRide(
    String requestId, {
    required int rating,
    required bool thankYou,
  });
}

class RideTrackingRemoteDataSourceImpl implements RideTrackingRemoteDataSource {
  RideTrackingRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  /// Signed kid photo URLs, re-signed before they expire.
  final Map<String, String> _photoUrls = {};
  DateTime? _photosSignedAt;

  @override
  Future<RideTracking> getTracking(
    String requestId, {
    bool includePath = false,
  }) async {
    final json = await _rpc<Map<String, dynamic>>(
      RideTrackingApiConstants.getRideTracking,
      {'requestId': requestId, 'includePath': includePath},
      'We couldn’t load the ride. Please try again.',
      parser: (json) {
        if (json is! Map) throw const ParsingException();
        return Map<String, dynamic>.from(json);
      },
    );
    final urls = await _signPhotos(RideTrackingModel.kidPhotoPaths(json));
    try {
      return RideTrackingModel.fromJson(json, photoUrls: urls);
    } on AppException {
      rethrow;
    } catch (_) {
      throw const ParsingException();
    }
  }

  @override
  Future<void> startRide(String requestId, RideFix? at) => _rpc<void>(
    RideTrackingApiConstants.startRide,
    {'requestId': requestId, ...?at?.toPointParams()},
    'We couldn’t start the ride. Please try again.',
    parser: (_) {},
  );

  @override
  Future<double?> updateLocation(String requestId, RideFix at) => _rpc(
    RideTrackingApiConstants.updateRideLocation,
    {'requestId': requestId, ...at.toLocationParams()},
    'We couldn’t share your location.',
    parser: (json) =>
        json is Map ? (json['distanceMiles'] as num?)?.toDouble() : null,
  );

  @override
  Future<void> markPickedUp(String requestId, RideFix? at) => _rpc<void>(
    RideTrackingApiConstants.markPickedUp,
    {'requestId': requestId, ...?at?.toPointParams()},
    'We couldn’t mark the pickup. Please try again.',
    parser: (_) {},
  );

  @override
  Future<RideCompletion> completeRide(String requestId, RideFix? at) => _rpc(
    RideTrackingApiConstants.completeRide,
    {'requestId': requestId, ...?at?.toPointParams()},
    'We couldn’t finish the ride. Please try again.',
    parser: RideTrackingModel.completionFromJson,
  );

  @override
  Future<void> triggerSos(String requestId, RideFix? at) => _rpc<void>(
    RideTrackingApiConstants.triggerSos,
    {'requestId': requestId, ...?at?.toPointParams()},
    'We couldn’t send the SOS. Call 911 if anyone is in danger.',
    parser: (_) {},
  );

  @override
  Future<void> rateRide(
    String requestId, {
    required int rating,
    required bool thankYou,
  }) => _rpc<void>(
    RideTrackingApiConstants.rateRide,
    {'requestId': requestId, 'rating': rating, 'thankYou': thankYou},
    'We couldn’t send your thanks. Please try again.',
    parser: (_) {},
  );

  Future<T> _rpc<T>(
    String name,
    Map<String, dynamic> params,
    String fallback, {
    required ResponseParser<T> parser,
  }) async {
    try {
      return await _apiClient.rpc<T>(name, params: params, parser: parser);
    } catch (error) {
      throw RideTrackingErrorMessages.map(error, fallback);
    }
  }

  /// Signs private kid photo paths; photos are optional, so failures (e.g.
  /// the Ride Partner can't read the bucket) just leave initials.
  Future<Map<String, String>> _signPhotos(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final signedAt = _photosSignedAt;
    final fresh =
        signedAt != null &&
        DateTime.now().difference(signedAt) <
            Duration(seconds: RideTrackingApiConstants.signedUrlSeconds - 600);
    if (fresh && paths.every(_photoUrls.containsKey)) return _photoUrls;
    try {
      final storageBase = '${_apiClient.baseUrl}${ApiConstants.storagePrefix}';
      final urls = await _apiClient.post<Map<String, String>>(
        '${ApiConstants.storagePrefix}/object/sign/'
        '${RideTrackingApiConstants.kidPhotosBucket}',
        data: {
          'expiresIn': RideTrackingApiConstants.signedUrlSeconds,
          'paths': paths,
        },
        parser: (json) {
          final out = <String, String>{};
          if (json is! List) return out;
          for (final item in json.whereType<Map>()) {
            final path = item['path'];
            final signed = item['signedURL'] ?? item['signedUrl'];
            if (path is String && signed is String) {
              out[path] = signed.startsWith('http')
                  ? signed
                  : '$storageBase$signed';
            }
          }
          return out;
        },
      );
      _photoUrls
        ..clear()
        ..addAll(urls);
      _photosSignedAt = DateTime.now();
      return _photoUrls;
    } on AppException {
      return const {};
    }
  }
}
