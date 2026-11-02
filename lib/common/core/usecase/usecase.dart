import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Contract for every use case: one responsibility, one `call`.
abstract interface class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Use for use cases that take no input.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
