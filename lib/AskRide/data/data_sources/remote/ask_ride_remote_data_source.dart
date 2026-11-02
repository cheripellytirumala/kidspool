import '../../../../core/network/api_client.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class AskRideRemoteDataSource {}

class AskRideRemoteDataSourceImpl implements AskRideRemoteDataSource {
  const AskRideRemoteDataSourceImpl(this._apiClient);

  // ignore: unused_field
  final ApiClient _apiClient;
}
