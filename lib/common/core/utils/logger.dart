import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Thin logging facade. Disabled entirely in production (see [EnvConfig]).
abstract final class AppLogger {
  static bool _enabled = false;

  static void configure({required bool enabled}) => _enabled = enabled;

  static bool get isEnabled => _enabled;

  static void debug(String message, {String tag = 'APP'}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void info(String message, {String tag = 'APP'}) =>
      _log(LogLevel.info, message, tag: tag);

  static void warning(String message, {String tag = 'APP'}) =>
      _log(LogLevel.warning, message, tag: tag);

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'APP',
  }) => _log(
    LogLevel.error,
    message,
    tag: tag,
    error: error,
    stackTrace: stackTrace,
  );

  static void _log(
    LogLevel level,
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    developer.log(
      '[${level.name.toUpperCase()}] $message',
      name: tag,
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _severity(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}
