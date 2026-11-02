import '../../../../common/core/error/exceptions.dart';
import '../../../../common/core/network/api_client.dart';
import '../../../../common/core/network/api_error_messages.dart';
import '../../../../common/core/network/auth_token_provider.dart';
import '../../../../common/domain/entities/picked_address.dart';
import '../../../core/constants/profile_api_constants.dart';
import '../../../domain/entities/profile_details.dart';
import '../../../domain/entities/saved_address.dart';
import '../../models/profile_details_model.dart';
import '../../models/saved_address_model.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class ProfileRemoteDataSource {
  Future<ProfileDetails> getDetails();

  Future<List<SavedAddress>> getMyAddresses();

  Future<void> addAddress(
    PickedAddress address, {
    required String label,
    required bool isDefault,
  });

  Future<void> setDefaultAddress(String addressId);

  Future<void> deleteAddress(String addressId);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  const ProfileRemoteDataSourceImpl({
    required ApiClient apiClient,
    required AuthTokenProvider tokenProvider,
  }) : _api = apiClient,
       _tokens = tokenProvider;

  final ApiClient _api;
  final AuthTokenProvider _tokens;

  @override
  Future<ProfileDetails> getDetails() {
    final userId = _tokens.session?.userId;
    if (userId == null || userId.isEmpty) {
      throw UnauthorizedException(
        ApiErrorMessages.forCode('not_authenticated')!,
        'not_authenticated',
      );
    }
    return _api.get(
      ProfileApiConstants.profilesTable,
      queryParameters: {
        'select': ProfileApiConstants.profileColumns,
        'id': 'eq.$userId',
      },
      parser: ProfileDetailsModel.fromJson,
    );
  }

  @override
  Future<List<SavedAddress>> getMyAddresses() => _api.rpc(
    ProfileApiConstants.getMyAddresses,
    parser: SavedAddressModel.listFromJson,
  );

  @override
  Future<void> addAddress(
    PickedAddress address, {
    required String label,
    required bool isDefault,
  }) => _api.rpc<void>(
    ProfileApiConstants.addAddress,
    params: {
      'addressLine1': address.street.trim(),
      'addressLine2': null,
      'city': address.city.trim(),
      'state': address.stateCode.trim(),
      'zip': address.zip.trim(),
      'latitude': address.latitude,
      'longitude': address.longitude,
      'label': label,
      'isDefault': isDefault,
    },
    parser: (_) {},
  );

  @override
  Future<void> setDefaultAddress(String addressId) => _api.rpc<void>(
    ProfileApiConstants.setDefaultAddress,
    params: {ProfileApiConstants.pAddressId: addressId},
    parser: (_) {},
  );

  @override
  Future<void> deleteAddress(String addressId) => _api.rpc<void>(
    ProfileApiConstants.deleteAddress,
    params: {ProfileApiConstants.pAddressId: addressId},
    parser: (_) {},
  );
}
