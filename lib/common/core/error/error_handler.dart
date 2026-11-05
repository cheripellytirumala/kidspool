import 'package:fpdart/fpdart.dart';

import '../utils/logger.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Converts data-layer exceptions into domain [Failure]s.
abstract final class ErrorHandler {
  static Failure toFailure(Object error) {
    return switch (error) {
      UnauthorizedException(:final message, :final code) => UnauthorizedFailure(
        message,
        code: code,
      ),
      NetworkException(:final message) => NetworkFailure(message),
      ServerException(
        :final message,
        :final statusCode,
        :final code,
        :final data,
      ) =>
        ServerFailure(message, statusCode: statusCode, code: code, data: data),
      CacheException(:final message) => CacheFailure(message),
      ParsingException(:final message) => ParsingFailure(message),
      DeviceException(:final message) => DeviceFailure(message),
      _ => const UnexpectedFailure(),
    };
  }

  /// Runs [action] and wraps its outcome in an [Either].
  ///
  /// Repositories call this for every operation so that no raw exception can
  /// reach the domain or presentation layers.
  static Future<Either<Failure, T>> guard<T>(
    Future<T> Function() action, {
    String? tag,
  }) async {
    try {
      return Right(await action());
    } catch (error, stackTrace) {
      AppLogger.error(
        '${tag ?? 'Repository'} failed',
        error: error,
        stackTrace: stackTrace,
      );
      return Left(toFailure(error));
    }
  }
}
