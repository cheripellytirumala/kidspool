/// Exceptions thrown by the data layer.
///
/// They never leave the data layer: repositories convert them into
/// [Failure]s (see `failures.dart`) before returning to the domain.
sealed class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType(statusCode: $statusCode, message: $message)';
}

/// No connectivity, DNS failure, timeouts, cancelled requests.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Please check your internet connection.',
  ]);
}

/// Non-2xx HTTP responses or 2xx responses whose business status is a failure.
class ServerException extends AppException {
  const ServerException([
    super.message = 'Something went wrong. Please try again.',
    int? statusCode,
  ]) : super(statusCode: statusCode);
}

/// 401 responses; lets the app trigger a logout / token refresh.
class UnauthorizedException extends ServerException {
  const UnauthorizedException([String message = 'Your session has expired.'])
    : super(message, 401);
}

/// Local storage read/write failures, or nothing cached.
class CacheException extends AppException {
  const CacheException([super.message = 'No cached data available.']);
}

/// Response body did not match the expected shape.
class ParsingException extends AppException {
  const ParsingException([super.message = 'Unexpected response from server.']);
}
