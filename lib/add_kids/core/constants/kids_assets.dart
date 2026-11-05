import '../../domain/entities/place.dart';

/// Paths of the design assets used by the Kids flow (F06–F12).
///
/// Several glyphs are exported at more than one size because the Figma
/// strokes stay 1.8–2px at every size; pick the file matching the slot.
abstract final class KidsAssets {
  static const String _icons = 'assets/icons';
  static const String _images = 'assets/images';

  // Navigation / actions
  static const String arrowLeft = '$_icons/kids_arrow_left.svg';
  static const String close = '$_icons/kids_close.svg';
  static const String plus = '$_icons/kids_plus.svg';
  static const String plus16 = '$_icons/kids_plus_16.svg';
  static const String plus18 = '$_icons/kids_plus_18.svg';
  static const String chevronRight = '$_icons/kids_chevron_right.svg';
  static const String pencil = '$_icons/kids_pencil.svg';
  static const String trash = '$_icons/kids_trash.svg';
  static const String search = '$_icons/kids_search.svg';
  static const String check = '$_icons/kids_check.svg';
  static const String check11 = '$_icons/kids_check_11.svg';
  static const String check18 = '$_icons/kids_check_18.svg';
  static const String shield16 = '$_icons/kids_shield_16.svg';
  static const String camera18 = '$_icons/kids_camera_18.svg';

  // Form fields (F06)
  static const String person = '$_icons/kids_person.svg';
  static const String cake = '$_icons/kids_cake.svg';
  static const String heart = '$_icons/kids_heart.svg';

  // People (tips)
  static const String people17 = '$_icons/kids_people_17.svg';
  static const String people18 = '$_icons/kids_people_18.svg';

  // Places
  static const String grad15 = '$_icons/kids_grad_15.svg';
  static const String grad16 = '$_icons/kids_grad_16.svg';
  static const String grad20 = '$_icons/kids_grad_20.svg';
  static const String grad21 = '$_icons/kids_grad_21.svg';
  static const String grad23 = '$_icons/kids_grad_23.svg';
  static const String grad25 = '$_icons/kids_grad_25.svg';
  static const String ball16 = '$_icons/kids_ball_16.svg';
  static const String ball24 = '$_icons/kids_ball_24.svg';
  static const String ball25 = '$_icons/kids_ball_25.svg';
  static const String soccer14 = '$_icons/kids_soccer_14.svg';
  static const String soccer20 = '$_icons/kids_soccer_20.svg';
  static const String swim14 = '$_icons/kids_swim_14.svg';
  static const String music14 = '$_icons/kids_music_14.svg';
  static const String music20 = '$_icons/kids_music_20.svg';
  static const String dance14 = '$_icons/kids_dance_14.svg';

  // Sample kid photos (cropped from the Figma photo sheet)
  static const String photoEmma = '$_images/kid_emma.png';
  static const String photoNoah = '$_images/kid_noah.png';

  /// Category glyph for a place, using the export closest to [size].
  static String placeIcon(PlaceCategory category, double size) {
    return switch (category) {
      PlaceCategory.school => switch (size) {
        <= 15 => grad15,
        <= 18 => grad16,
        <= 20 => grad20,
        <= 22 => grad21,
        <= 24 => grad23,
        _ => grad25,
      },
      PlaceCategory.soccer => switch (size) {
        <= 15 => soccer14,
        <= 18 => ball16,
        <= 21 => soccer20,
        <= 24 => ball24,
        _ => ball25,
      },
      PlaceCategory.music => size <= 16 ? music14 : music20,
      PlaceCategory.swim => swim14,
      PlaceCategory.dance => dance14,
      // Any other activity: the generic ball used by the "Activity" tab.
      PlaceCategory.activity => switch (size) {
        <= 18 => ball16,
        <= 24 => ball24,
        _ => ball25,
      },
    };
  }
}
