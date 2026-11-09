import 'package:fpdart/fpdart.dart';

import '../../../add_kids/domain/repositories/kids_repository.dart';
import '../../../common/core/error/failures.dart';
import '../../../common/core/usecase/usecase.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../../messages/domain/entities/ride_group.dart';
import '../../../messages/domain/repositories/messages_repository.dart';
import '../entities/profile_details.dart';
import '../entities/profile_overview.dart';
import '../repositories/profile_repository.dart';

/// Loads every section of the profile in parallel. Fails only when
/// `get_my_status` fails; kids and addresses report their own errors.
class GetProfileOverview implements UseCase<ProfileOverview, NoParams> {
  const GetProfileOverview({
    required ProfileRepository profile,
    required AccountRepository account,
    required KidsRepository kids,
    required MessagesRepository messages,
  }) : _profile = profile,
       _account = account,
       _kids = kids,
       _messages = messages;

  final ProfileRepository _profile;
  final AccountRepository _account;
  final KidsRepository _kids;
  final MessagesRepository _messages;

  @override
  Future<Either<Failure, ProfileOverview>> call(NoParams params) async {
    final statusF = _account.getMyStatus();
    final detailsF = _profile.getDetails();
    final kidsF = _kids.getKids();
    final addressesF = _profile.getAddresses();
    final groupsF = _messages.getMyGroups();

    final status = await statusF;
    final details = await detailsF;
    final kids = await kidsF;
    final addresses = await addressesF;
    final groups = await groupsF;

    return status.map(
      (me) => ProfileOverview(
        status: me,
        rideMode: _profile.getRideMode(),
        details: details.getOrElse((_) => const ProfileDetails()),
        kids: kids.getOrElse((_) => const []),
        kidsError: kids.getLeft().toNullable()?.message,
        addresses: addresses.getOrElse((_) => const []),
        addressesError: addresses.getLeft().toNullable()?.message,
        // Optional section: hidden when groups can't load (or the groups
        // SQL isn't applied yet).
        rideGroups: _newestFirst(groups.getOrElse((_) => const [])),
      ),
    );
  }

  static List<RideGroup> _newestFirst(List<RideGroup> groups) {
    final list = [...groups];
    list.sort((a, b) {
      final at = a.lastAt, bt = b.lastAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return list;
  }
}
