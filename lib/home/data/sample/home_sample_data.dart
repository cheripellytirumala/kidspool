import '../../core/constants/home_assets.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/kid_place.dart';
import '../../domain/entities/ride_summary.dart';

/// Static sample data matching the Figma frames (no API yet).
abstract final class HomeSampleData {
  static const String userFirstName = 'Sarah';
  static const String userAvatarAsset = HomeAssets.avatarSarah;

  static const KidPlace lincoln = KidPlace(
    id: 'lincoln',
    name: 'Lincoln',
    kind: KidPlaceKind.school,
  );
  static const KidPlace lincolnElementary = KidPlace(
    id: 'lincoln-elementary',
    name: 'Lincoln Elementary',
    kind: KidPlaceKind.activity,
  );

  static const List<KidPlace> places = [lincoln, lincolnElementary];

  static const List<Family> families = [
    Family(
      id: 'jen',
      parentName: 'Jen P.',
      childLabel: 'Mia',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 0.4,
      avatarAsset: HomeAssets.avatarJen,
      placeIds: {'lincoln'},
      givesRides: true,
    ),
    Family(
      id: 'david',
      parentName: 'David C.',
      childLabel: 'Leo',
      placeName: 'Lincoln',
      shortPlaceName: 'Lincoln',
      distanceMiles: 0.8,
      avatarAsset: HomeAssets.avatarDavid,
      placeIds: {'lincoln'},
      needsRides: true,
    ),
    Family(
      id: 'scott',
      parentName: 'Scott R.',
      childLabel: 'Ava',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 1.2,
      avatarAsset: HomeAssets.avatarScott,
      placeIds: {'lincoln', 'lincoln-elementary'},
      givesRides: true,
    ),
    Family(
      id: 'maria',
      parentName: 'Maria R.',
      childLabel: 'Lucas',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 0.8,
      avatarAsset: HomeAssets.avatarMaria,
      placeIds: {'lincoln'},
      givesRides: true,
      needsRides: true,
    ),
    Family(
      id: 'kevin',
      parentName: 'Kevin L.',
      childLabel: 'Owen',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 1.4,
      avatarAsset: HomeAssets.avatarKevin,
      placeIds: {'lincoln', 'lincoln-elementary'},
      needsRides: true,
    ),
    Family(
      id: 'rachel',
      parentName: 'Rachel S.',
      childLabel: 'Ethan',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 1.1,
      avatarAsset: HomeAssets.avatarRachel,
      placeIds: {'lincoln'},
      givesRides: true,
    ),
    Family(
      id: 'ruth',
      parentName: 'Ruth B.',
      childLabel: 'Grandson Jack',
      placeName: 'Lincoln Elementary',
      shortPlaceName: 'Lincoln',
      distanceMiles: 2.1,
      avatarAsset: HomeAssets.avatarRuth,
      placeIds: {'lincoln', 'lincoln-elementary'},
      givesRides: true,
    ),
  ];

  /// Families shown on the Home dashboard preview (Figma order).
  static const List<String> previewFamilyIds = ['jen', 'david', 'rachel'];

  static const RideSummary pendingRide = RideSummary(
    childName: 'Emma',
    childAvatarAsset: HomeAssets.avatarEmma,
    from: 'Home',
    to: 'Lincoln',
    schedule: 'Tue & Thu 8:30 AM · weekly · return 3:30 PM',
  );

  static const String messageTemplate =
      'Hi! I’m Sarah, Our kids both go to Lincoln Elementary. Would you like '
      'to share school rides? We could take turns driving.';
}
