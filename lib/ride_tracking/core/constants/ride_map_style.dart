/// Google Maps style matching the Figma "Map/Dark" tile: near-black ground,
/// dark grey streets, muted labels, no POI clutter.
abstract final class RideMapStyle {
  static const String dark = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#141414"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#141414"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#2e2e2e"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"visibility": "on"}, {"color": "#1d2a1a"}]},
  {"featureType": "poi.school", "elementType": "geometry", "stylers": [{"visibility": "on"}, {"color": "#1f2a14"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2e2e2e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1a1a1a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#363636"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3d3d3d"}]},
  {"featureType": "road.local", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0b0b0b"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';
}
