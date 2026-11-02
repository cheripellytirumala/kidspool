import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/utils/json_parser.dart';
import '../../../core/constants/ask_ride_api_constants.dart';
import '../../../domain/entities/ride_request_result.dart';
import '../../../domain/entities/saved_place.dart';
import '../../../../common/domain/entities/picked_address.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class AskRideRemoteDataSource {
  Future<List<SavedPlace>> getMyAddresses();

  /// Saves an address chosen on the map (not as the default).
  Future<void> addAddress(PickedAddress address, {required String label});

  Future<RideRequestResult> createRideRequest(CreateRideParams params);
}

class AskRideRemoteDataSourceImpl implements AskRideRemoteDataSource {
  const AskRideRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> addAddress(PickedAddress address, {required String label}) {
    return _apiClient.rpc<void>(
      AskRideApiConstants.addAddress,
      params: {
        'addressLine1': address.street.trim(),
        'addressLine2': null,
        'city': address.city.trim(),
        'state': address.stateCode.trim(),
        'zip': address.zip.trim(),
        'latitude': address.latitude,
        'longitude': address.longitude,
        'label': label,
        'isDefault': false,
      },
      parser: (_) {},
    );
  }

  @override
  Future<List<SavedPlace>> getMyAddresses() {
    return _apiClient.rpc(
      AskRideApiConstants.getMyAddresses,
      parser: (json) {
        if (json is! List) throw const ParsingException();
        return json
            .whereType<Map>()
            .map((e) {
              final a = Map<String, dynamic>.from(e);
              final label = a.readString('label') ?? 'Home';
              final line1 = a.readString('addressLine1') ?? '';
              return SavedPlace(
                id: a.readString('id') ?? '',
                name: line1.isEmpty ? label : '$label · $line1',
                address: [
                  line1,
                  a.readString('city'),
                ].whereType<String>().where((p) => p.isNotEmpty).join(', '),
                kind: PlaceKind.home,
                detail: a.readBool('isDefault') == true ? 'default' : null,
              );
            })
            .toList(growable: false);
      },
    );
  }

  @override
  Future<RideRequestResult> createRideRequest(CreateRideParams p) {
    final d = p.pickupDate;
    final note = p.note.trim();
    return _apiClient.rpc(
      AskRideApiConstants.createRideRequest,
      params: {
        'kidIds': p.kidIds,
        'pickupDate':
            '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
        'pickupTime': p.pickupTime,
        'timeZone': p.timeZone,
        'pickupAddressId': p.pickupAddressId,
        'note': note.isEmpty ? null : note,
        'repeatSchoolDays': false,
        'requireApproval': false,
      },
      parser: (json) {
        if (json is! Map) throw const ParsingException();
        final map = Map<String, dynamic>.from(json);
        return RideRequestResult(
          requestIds: map
              .readList('requests', (r) => r.readString('id') ?? '')
              .where((id) => id.isNotEmpty)
              .toList(growable: false),
          eligibleDriversCount: map.readInt('eligibleDriversCount') ?? 0,
        );
      },
    );
  }
}
