import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/app_version.dart';
import '../repositories/app_version_repository.dart';

class GetAppVersion implements UseCase<AppVersion, GetAppVersionParams> {
  const GetAppVersion(this._repository);

  final AppVersionRepository _repository;

  @override
  Future<Either<Failure, AppVersion>> call(GetAppVersionParams params) {
    return _repository.getAppVersion(params);
  }
}

class GetAppVersionParams extends Equatable {
  const GetAppVersionParams({required this.platform, required this.appVersion});

  /// `ios` or `android`.
  final String platform;

  /// Version of the running build, e.g. `1.0.1`.
  final String appVersion;

  @override
  List<Object?> get props => [platform, appVersion];
}
