import '../../../../core/network/api_client.dart';

/// Throws only `AppException` subtypes; never returns raw JSON.
abstract interface class AuthRemoteDataSource {}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._apiClient);

  // ignore: unused_field
  final ApiClient _apiClient;
}
