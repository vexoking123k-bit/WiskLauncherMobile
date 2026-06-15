import 'dart:async';
import 'dart:developer' as developer;

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime at;
  final LogLevel level;
  final String tag;
  final String message;

  const LogEntry(this.at, this.level, this.tag, this.message);

  String format() {
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final ss = at.second.toString().padLeft(2, '0');
    final ms = at.millisecond.toString().padLeft(3, '0');
    final lvl = switch (level) {
      LogLevel.debug => 'DBG',
      LogLevel.info  => 'INF',
      LogLevel.warn  => 'WRN',
      LogLevel.error => 'ERR',
    };
    return '$hh:$mm:$ss.$ms $lvl ${tag.padRight(12)} $message';
  }
}

/// Global launcher log. Anything in the codebase can call
/// `AppLogger.instance.info('tag', 'message')` and it shows up in the in-app
/// Logs page (via the Riverpod provider hook in providers.dart) and the
/// platform dev console.
///
/// The stream is broadcast, so subscribing late is fine — but you only see
/// entries emitted after you subscribe. The in-memory ring buffer
/// (`recent`) is kept so the Logs page can render the last N lines on first
/// build without a stream gap.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _bufferSize = 2000;
  final _controller = StreamController<LogEntry>.broadcast();
  final List<LogEntry> _recent = [];

  Stream<LogEntry> get stream => _controller.stream;
  List<LogEntry> get recent => List.unmodifiable(_recent);

  void clear() {
    _recent.clear();
    _emit(LogLevel.info, 'log', 'Cleared.');
  }

  void debug(String tag, String message) => _emit(LogLevel.debug, tag, message);
  void info(String tag, String message) => _emit(LogLevel.info, tag, message);
  void warn(String tag, String message) => _emit(LogLevel.warn, tag, message);
  void error(String tag, String message, [Object? cause]) {
    _emit(LogLevel.error, tag, cause == null ? message : '$message — $cause');
  }

  void _emit(LogLevel level, String tag, String message) {
    final entry = LogEntry(DateTime.now(), level, tag, message);
    _recent.add(entry);
    if (_recent.length > _bufferSize) {
      _recent.removeRange(0, _recent.length - _bufferSize);
    }
    _controller.add(entry);
    developer.log(message, name: tag);
  }
}
