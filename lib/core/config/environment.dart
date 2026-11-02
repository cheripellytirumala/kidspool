import '../constants/api_constants.dart';

/// Build flavours supported by the app.
///
/// Select one at build time:
/// `flutter run --dart-define=ENV=dev|staging|production`
enum Environment { dev, staging, production }

/// Immutable, environment-specific configuration resolved once at startup.
class EnvConfig {
  const EnvConfig._({
    required this.environment,
    required this.configBaseUrl,
    required this.enableLogging,
  });

  final Environment environment;

  /// Base URL of the configuration/admin API (hosts `getAppVersion`).
  final String configBaseUrl;

  /// Network + app logging. Always off in production.
  final bool enableLogging;

  bool get isProduction => environment == Environment.production;

  static const _envKey = 'ENV';

  /// Resolves the config from `--dart-define=ENV=...`, defaulting to dev.
  factory EnvConfig.fromDartDefine() {
    const raw = String.fromEnvironment(_envKey, defaultValue: 'dev');
    return EnvConfig.of(_parse(raw));
  }

  factory EnvConfig.of(Environment environment) {
    switch (environment) {
      case Environment.dev:
        return const EnvConfig._(
          environment: Environment.dev,
          configBaseUrl: ApiConstants.devConfigBaseUrl,
          enableLogging: true,
        );
      case Environment.staging:
        return const EnvConfig._(
          environment: Environment.staging,
          configBaseUrl: ApiConstants.stagingConfigBaseUrl,
          enableLogging: true,
        );
      case Environment.production:
        return const EnvConfig._(
          environment: Environment.production,
          configBaseUrl: ApiConstants.productionConfigBaseUrl,
          enableLogging: false,
        );
    }
  }

  static Environment _parse(String raw) {
    return Environment.values.firstWhere(
      (e) => e.name == raw.toLowerCase(),
      orElse: () => Environment.dev,
    );
  }
}
