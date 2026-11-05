import 'package:get_it/get_it.dart';

import '../../data/data_sources/local/home_local_data_source.dart';
import '../../data/data_sources/remote/home_remote_data_source.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_families_near_me.dart';
import '../../presentation/providers/families_near_you_provider.dart';
import '../../presentation/providers/home_provider.dart';
import '../../../ask_ride/domain/entities/ride_schedule.dart';
import '../../../ask_ride/presentation/providers/ask_ride_provider.dart';
import '../../domain/entities/ride_summary.dart';

/// Registers everything owned by the Home feature group.
/// Called from `lib/core/di/injection_container.dart`.
void registerHomeDependencies(GetIt sl) {
  // Data sources
  sl
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<HomeLocalDataSource>(
      () => HomeLocalDataSourceImpl(sl()),
    )
    // Repository
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()),
    )
    // Use cases
    ..registerLazySingleton<GetFamiliesNearMe>(() => GetFamiliesNearMe(sl()))
    // Providers
    // Shared across screens (role survives navigation).
    ..registerLazySingleton<HomeProvider>(
      () => HomeProvider(
        repository: sl(),
        account: sl(),
        preferences: sl(),
        getFamiliesNearMe: sl(),
      ),
    )
    // Per-screen state: fresh for every "Families near you" visit.
    ..registerFactory<FamiliesNearYouProvider>(
      () => FamiliesNearYouProvider(
        getFamiliesNearMe: sl(),
        account: sl(),
        rideSummary: () => _askRideSummary(sl<AskRideProvider>()),
      ),
    );
}

/// The ride being asked for on "Ask for a ride", for the select-mode card;
/// `null` when no kid is chosen yet.
RideSummary? _askRideSummary(AskRideProvider askRide) {
  final draft = askRide.draft;
  final kids = [
    for (final kid in askRide.kids)
      if (draft.kidIds.contains(kid.id)) kid,
  ];
  if (kids.isEmpty) return null;
  String short(String? name) => (name ?? '').split(' · ').first.trim();
  final names = kids.map((k) => k.name).toList();
  final childName = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} & ${names.last}';
  final schedule = [
    switch (draft.schedule) {
      OnceSchedule() => askRide.onceSummary.replaceAll(' | ', ' '),
      CustomSchedule() => askRide.customSummary.replaceAll(' | ', ' '),
      _ => draft.pickupTime?.format() ?? '',
    },
    if (draft.returnTrip && draft.returnTime != null)
      'return ${draft.returnTime!.format()}',
  ].where((p) => p.isNotEmpty).join(' · ');
  return RideSummary(
    childName: childName,
    childPhoto: kids.first.photo,
    from: short(draft.pickup?.name).isEmpty
        ? 'Pick-up'
        : short(draft.pickup?.name),
    to: short(draft.dropOff?.name).isEmpty
        ? 'Drop-off'
        : short(draft.dropOff?.name),
    schedule: schedule,
  );
}
