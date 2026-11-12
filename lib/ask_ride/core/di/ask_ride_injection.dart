import 'package:get_it/get_it.dart';

import '../../domain/entities/saved_place.dart';
import '../../../add_kids/data/data_sources/local/kid_activities_store.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../messages/domain/usecases/get_my_ride_groups.dart';
import '../../../messages/domain/usecases/get_ride_group.dart';
import '../../../messages/core/constants/messages_api_constants.dart';
import '../../../messages/domain/usecases/ride_asks.dart';
import '../../../messages/domain/usecases/send_group_message.dart';

import '../../data/data_sources/local/ask_ride_local_data_source.dart';
import '../../data/data_sources/remote/ask_ride_remote_data_source.dart';
import '../../data/repositories/ask_ride_repository_impl.dart';
import '../../domain/repositories/ask_ride_repository.dart';
import '../../domain/usecases/add_saved_place.dart';
import '../../domain/usecases/get_ride_options.dart';
import '../../domain/usecases/search_drop_off_places.dart';
import '../../presentation/providers/drop_off_search_provider.dart';
import '../../presentation/providers/ask_ride_provider.dart';

/// Registers everything owned by the AskRide feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerAskRideDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<AskRideRemoteDataSource>(
      () => AskRideRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AskRideLocalDataSource>(
      () => AskRideLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<AskRideRepository>(
      () => AskRideRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        kidsRepository: sl(),
      ),
    )
    // Use cases
    ..registerLazySingleton<GetRideOptions>(() => GetRideOptions(sl()))
    ..registerLazySingleton<AddSavedPlace>(() => AddSavedPlace(sl()))
    ..registerLazySingleton<SearchDropOffPlaces>(
      () => SearchDropOffPlaces(sl()),
    )
    // One per "Drop off at" sheet.
    ..registerFactory<DropOffSearchProvider>(
      () => DropOffSearchProvider(searchPlaces: sl()),
    )
    // Provider: lazy singleton so the ride request draft survives the
    // families screen (F19) and the "Message sent" screen (F20). Screens
    // expose it with `ChangeNotifierProvider.value(value: sl<AskRideProvider>())`.
    ..registerLazySingleton<AskRideProvider>(
      () => AskRideProvider(
        getRideOptions: sl(),
        addSavedPlace: sl(),
        repository: sl(),
        timeZone: sl(),
        findGroup: (school) => _findGroupForSchool(sl, school),
        activities: () => [
          for (final a in sl<KidActivitiesStore>().read())
            (
              place: SavedPlace(
                id: 'activity:${a.place.id}',
                name: a.place.name,
                address: a.place.details.isNotEmpty
                    ? a.place.details
                    : a.place.addressLine,
                kind: PlaceKind.custom,
                detail: 'Activity',
                latitude: a.place.latitude,
                longitude: a.place.longitude,
                addressLine1: a.place.addressLine.isNotEmpty
                    ? a.place.addressLine
                    : a.place.name,
                city: a.place.city,
                state: a.place.state,
                zip: a.place.zip,
              ),
              kidIds: a.childIds,
            ),
        ],
        postAsk: (groupId, rides, summary) async {
          final result = await sl<PostRideAsk>()(
            PostRideAskParams(
              groupId: groupId,
              rides: [
                for (final r in rides)
                  AskRideRemoteDataSourceImpl.createRideParams(r),
              ],
              summary: summary,
            ),
          );
          final failure = result.getLeft().toNullable();
          return (
            failure?.code != MessagesApiConstants.rideAsksMissing,
            failure?.message,
          );
        },
        postToGroup: (groupId, text) async => (await sl<SendGroupMessage>()(
          SendGroupMessageParams(groupId: groupId, body: text),
        )).getLeft().toNullable()?.message,
      ),
    );
}

/// How many recent groups to look through for a matching school.
const int _groupsToCheck = 10;

/// The user's most recently active ride group about [school] that still
/// has other families in it; null when there is none (or groups aren't on
/// the server).
Future<RideGroupTarget?> _findGroupForSchool(GetIt sl, String school) async {
  final wanted = school.trim().toLowerCase();
  final groups = (await sl<GetMyRideGroups>()(
    const NoParams(),
  )).getOrElse((_) => const []);
  for (final g in groups.take(_groupsToCheck)) {
    if (g.memberCount < 2) continue;
    final details = (await sl<GetRideGroup>()(g.id)).toNullable();
    if (details?.schoolName?.trim().toLowerCase() == wanted) {
      return RideGroupTarget(id: g.id, name: g.name);
    }
  }
  return null;
}
