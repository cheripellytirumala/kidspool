import '../../domain/repositories/ask_ride_repository.dart';
import '../data_sources/local/ask_ride_local_data_source.dart';
import '../data_sources/remote/ask_ride_remote_data_source.dart';

/// Wrap every method body in `ErrorHandler.guard` so exceptions become
/// failures before leaving the data layer.
class AskRideRepositoryImpl implements AskRideRepository {
  const AskRideRepositoryImpl({
    required AskRideRemoteDataSource remoteDataSource,
    required AskRideLocalDataSource localDataSource,
  }) : _remote = remoteDataSource,
       _local = localDataSource;

  // ignore: unused_field
  final AskRideRemoteDataSource _remote;
  // ignore: unused_field
  final AskRideLocalDataSource _local;
}
