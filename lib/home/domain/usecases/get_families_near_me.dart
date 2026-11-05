import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../entities/family.dart';
import '../repositories/home_repository.dart';

/// "Families near you": other approved parents whose kids share a school
/// with the user's kids, nearest first (`get_families_near_me`).
class GetFamiliesNearMe
    implements UseCase<FamiliesNearMe, GetFamiliesNearMeParams> {
  const GetFamiliesNearMe(this._repository);

  final HomeRepository _repository;

  @override
  Future<Either<Failure, FamiliesNearMe>> call(
    GetFamiliesNearMeParams params,
  ) => _repository.getFamiliesNearMe(
    schoolId: params.schoolId,
    radiusMiles: params.radiusMiles,
  );
}

class GetFamiliesNearMeParams extends Equatable {
  const GetFamiliesNearMeParams({this.schoolId, this.radiusMiles});

  /// Only this school of the user's kids; null = all of them.
  final String? schoolId;

  /// Search radius around the user's home; null = server default (10 mi).
  final double? radiusMiles;

  @override
  List<Object?> get props => [schoolId, radiusMiles];
}
