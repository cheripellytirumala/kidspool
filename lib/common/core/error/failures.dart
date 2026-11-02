import 'package:equatable/equatable.dart';

/// Domain-level error returned in `Either<Failure, T>`.
///
/// Shared by every feature group's domain layer, which is why it lives in the
/// shared kernel rather than in a single feature's `domain/`.
sealed class Failure extends Equatable {
  const Failure(
    this.message, {
    this.statusCode,
    this.code,
    this.data = const {},
  });

  final String message;
  final int? statusCode;

  /// Backend error code (e.g. `role_already_set`), when there is one.
  final String? code;

  /// Extra error fields from the backend (e.g. `retryAfter`, `field`).
  final Map<String, dynamic> data;

  @override
  List<Object?> get props => [message, statusCode, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.statusCode,
    super.code,
    super.data,
  });
}

class UnauthorizedFailure extends ServerFailure {
  const UnauthorizedFailure(super.message, {super.code})
    : super(statusCode: 401);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ParsingFailure extends Failure {
  const ParsingFailure(super.message);
}

class DeviceFailure extends Failure {
  const DeviceFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}
