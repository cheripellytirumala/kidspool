import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// The "I need rides" / "I can offer and request rides" choice saved on this
/// device (About you, Profile). Parents who only need rides skip the ID /
/// driver's license step; only parents who offer rides scan their license.
abstract final class RideModeStore {
  /// Value saved for "I need rides" (`RideRole.seeker` / `RideMode.seeker`).
  static const String riderOnlyValue = 'seeker';

  static bool isRiderOnly(SharedPreferences preferences) =>
      preferences.getString(AppConstants.cacheKeyRideRole) == riderOnlyValue;
}
