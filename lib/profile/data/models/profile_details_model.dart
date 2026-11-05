import '../../../common/core/error/exceptions.dart';
import '../../../common/core/utils/json_parser.dart';
import '../../domain/entities/profile_details.dart';

/// Parses `GET rest/v1/profiles?select=first_name,last_name,full_name,phone`.
abstract final class ProfileDetailsModel {
  static ProfileDetails fromJson(dynamic json) {
    final row = switch (json) {
      List list when list.isNotEmpty && list.first is Map => list.first as Map,
      List _ => null,
      Map map => map,
      _ => throw const ParsingException('Invalid profile response.'),
    };
    if (row == null) return const ProfileDetails();
    final map = Map<String, dynamic>.from(row);
    var first = map.readString('first_name')?.trim() ?? '';
    var last = map.readString('last_name')?.trim() ?? '';
    if (first.isEmpty) {
      // Older rows only have the sign-up name.
      final full = (map.readString('full_name') ?? '').trim().split(
        RegExp(r'\s+'),
      );
      first = full.first;
      last = full.skip(1).join(' ');
    }
    return ProfileDetails(
      firstName: first,
      lastName: last,
      phone: map.readString('phone'),
    );
  }
}
