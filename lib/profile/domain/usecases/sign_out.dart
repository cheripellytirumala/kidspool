import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/error_handler.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/repositories/account_repository.dart';

/// Log out: forgets the stored Supabase session on this device.
class SignOut implements UseCase<Unit, NoParams> {
  const SignOut(this._account);

  final AccountRepository _account;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) =>
      ErrorHandler.guard(tag: 'Profile.signOut', () async {
        await _account.signOut();
        return unit;
      });
}
