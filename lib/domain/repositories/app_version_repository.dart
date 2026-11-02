import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/app_version.dart';
import '../usecases/get_app_version.dart';

abstract interface class AppVersionRepository {
  Future<Either<Failure, AppVersion>> getAppVersion(GetAppVersionParams params);
}
