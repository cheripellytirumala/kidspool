import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/network/auth_token_provider.dart';
import '../../domain/entities/ride_alert.dart';
import '../../domain/repositories/ride_alerts_repository.dart';
import '../data_sources/remote/ride_alerts_remote_data_source.dart';

class RideAlertsRepositoryImpl implements RideAlertsRepository {
  const RideAlertsRepositoryImpl({
    required RideAlertsRemoteDataSource remoteDataSource,
    required AuthTokenProvider tokenProvider,
  }) : _remote = remoteDataSource,
       _tokens = tokenProvider;

  final RideAlertsRemoteDataSource _remote;
  final AuthTokenProvider _tokens;

  @override
  bool get isSignedIn => _tokens.hasSession;

  @override
  Future<Either<Failure, List<RideAlert>>> getRideAlerts() =>
      ErrorHandler.guard(_remote.getRideAlerts, tag: 'RideAlertsRepository');
}
