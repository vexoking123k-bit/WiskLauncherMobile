/// Base exception for all launcher-side errors. Carrying a `code` makes UI
/// branching easy without string-matching `message`.
class LauncherException implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const LauncherException(this.code, this.message, {this.cause});

  @override
  String toString() => 'LauncherException($code): $message';
}

class NetworkException extends LauncherException {
  const NetworkException(String message, {Object? cause})
      : super('network', message, cause: cause);
}

class ChecksumException extends LauncherException {
  const ChecksumException(String message) : super('checksum', message);
}

class AuthException extends LauncherException {
  const AuthException(String message, {Object? cause})
      : super('auth', message, cause: cause);
}

class PlatformUnsupportedException extends LauncherException {
  const PlatformUnsupportedException(String message)
      : super('platform_unsupported', message);
}
