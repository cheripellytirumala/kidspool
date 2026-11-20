import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../../../ride_tracking/domain/entities/ride_tracking.dart';

/// Launches the device's map app (Google Maps or Apple Maps) for navigation.
abstract final class ExternalMapsLauncher {
  /// Opens the map app for turn-by-turn navigation to [stop].
  static Future<bool> launchNavigation(RideStop stop) async {
    final point = stop.point;
    if (point == null) return false;

    final lat = point.latitude;
    final lng = point.longitude;

    if (Platform.isAndroid) {
      final googleMapsUrl = Uri.parse('google.navigation:q=$lat,$lng');
      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(googleMapsUrl);
      }
    } else if (Platform.isIOS) {
      final googleMapsUrl = Uri.parse(
        'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
      );
      final appleMapsUrl = Uri.parse(
        'http://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
      );

      if (await canLaunchUrl(googleMapsUrl)) {
        return await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        return await launchUrl(appleMapsUrl);
      }
    }

    // Google Maps directions (app if installed, else the browser): it
    // shows the route and every alternative, and starts navigation.
    final directions = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
      '&travelmode=driving&dir_action=navigate',
    );
    if (await launchUrl(directions, mode: LaunchMode.externalApplication)) {
      return true;
    }

    // Last resort: the device's map app at the stop.
    final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    return launchUrl(geoUrl);
  }
}
