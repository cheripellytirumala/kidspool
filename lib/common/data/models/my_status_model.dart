import '../../core/error/exceptions.dart';
import '../../core/utils/json_parser.dart';
import '../../domain/entities/my_status.dart';

/// Parses the `get_my_status` RPC response.
abstract final class MyStatusModel {
  static MyStatus fromJson(dynamic json) {
    if (json is! Map) throw const ParsingException('Invalid status response.');
    final map = Map<String, dynamic>.from(json);
    final identity = map['identity'];
    final driver = map['driver'];
    return MyStatus(
      role: map.readString('role'),
      firstName: map.readString('firstName') ?? '',
      lastName: map.readString('lastName') ?? '',
      onboardingStatus: OnboardingStatus.parse(
        map.readString('onboardingStatus'),
      ),
      rejectionReason: identity is Map
          ? Map<String, dynamic>.from(identity).readString('rejectionReason')
          : null,
      kidsCount: map.readInt('kidsCount') ?? 0,
      hasDefaultAddress: map.readBool('hasDefaultAddress') ?? false,
      licenseStatus: OnboardingStatus.parse(map.readString('driverStatus')),
      licenseRejectionReason: driver is Map
          ? Map<String, dynamic>.from(driver).readString('rejectionReason')
          : null,
    );
  }
}
