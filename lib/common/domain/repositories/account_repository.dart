import 'package:fpdart/fpdart.dart';

import '../../core/error/failures.dart';
import '../entities/my_status.dart';

/// The signed-in account, shared by every feature group.
abstract interface class AccountRepository {
  /// True when a Supabase session is stored on the device.
  bool get isSignedIn;

  Future<Either<Failure, MyStatus>> getMyStatus();

  Future<void> signOut();
}
