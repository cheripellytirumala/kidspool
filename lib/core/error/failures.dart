import 'package:equatable/equatable.dart';

/// Domain-level error returned in `Either<Failure, T>`.
///
/// Shared by every feature group's domain layer, which is why it lives in the
/// shared kernel rather than in a single feature's `domain/`.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class UnauthorizedFailure extends ServerFailure {
  const UnauthorizedFailure(super.message) : super(statusCode: 401);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class ParsingFailure extends Failure {
  const ParsingFailure(super.message);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred.']);
}
