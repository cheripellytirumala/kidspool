import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../entities/app_notification.dart';

abstract interface class NotificationsRepository {
  /// Newest first.
  Future<Either<Failure, List<AppNotification>>> getNotifications();

  /// Newest notification time the user has already seen (bell dot), or
  /// null when they never opened the list.
  DateTime? get seenAt;

  /// Everything up to [at] counts as seen.
  Future<Either<Failure, Unit>> markSeen(DateTime at);
}
