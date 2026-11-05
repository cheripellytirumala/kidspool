import 'package:get_it/get_it.dart';

import '../../presentation/providers/rides_provider.dart';

/// Registers the Rides tab (F19c). Data comes from the Messages feature
/// (`GetRequestsInbox`, `GetMyRides`) and Profile (ride mode), so call this
/// after both are registered.
void registerRidesDependencies(GetIt sl) {
  sl.registerFactory<RidesProvider>(
    () => RidesProvider(
      getRequestsInbox: sl(),
      getMyRides: sl(),
      profile: sl(),
      changeRideMode: sl(),
    ),
  );
}
