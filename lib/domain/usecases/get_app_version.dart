import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../../core/usecase/usecase.dart';
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
  const GetAppVersionParams({
    required this.roleId,
    required this.device,
    required this.versionNumber,
  });

  final int roleId;

  /// `ios` or `android`.
  final String device;

  /// Version of the running build, e.g. `2.0`.
  final String versionNumber;

  @override
  List<Object?> get props => [roleId, device, versionNumber];
}
