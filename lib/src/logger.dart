import 'package:chary/chary.dart';

import 'context.dart';
import 'formatter.dart';
import 'log_entry.dart';
import 'level.dart';
import 'sink.dart';

/// Callback invoked with each [LogEntry] that passes the level filter.
///
/// A handler receives the fully-formed entry (with zone context merged)
/// and is responsible for formatting and outputting it. Wire one up with
/// [makeHandler] or use [Logger.init] for the common case.
typedef LogHandler = void Function(LogEntry entry);

/// A named, level-filtered logger.
///
/// Loggers are retrieved by name via [Logger.get]. Each name maps to exactly
/// one logger instance (singleton per name). All loggers share the global
/// [Logger.level] threshold unless overridden individually via
/// [Logger.loggerLevel].
///
/// ```dart
/// Logger.init();
/// final log = Logger.get('myService');
/// log.info('server started', [CharyValue('port', 8080)]);
/// ```
class Logger {
  /// Global minimum level. Entries below this are discarded.
  /// Individual loggers can override with [loggerLevel].
  static Level level = Level.info;

  /// Global handler. Called for every entry that passes the level check.
  /// Set this once at startup via [init] or directly.
  static LogHandler handler = _defaultHandler;

  static final Map<String, Logger> _loggers = {};

  /// Configures logging for the common case.
  ///
  /// Call once at startup. Uses pretty console output by default,
  /// or JSON when [json] is true (for production / cloud ingestion).
  ///
  /// ```dart
  /// // Development (default)
  /// Logger.init();
  ///
  /// // Production
  /// Logger.init(json: true, level: Level.warn);
  /// ```
  static void init({
    bool json = false,
    bool color = true,
    Level level = Level.info,
  }) {
    Logger.level = level;
    final formatter = json ? jsonFormatter() : prettyFormatter(color: color);
    handler = makeHandler(formatter, stdoutSink());
  }

  /// Returns the logger for [name], creating it on first access.
  ///
  /// Same name always returns the same instance.
  static Logger get(String name) =>
      _loggers.putIfAbsent(name, () => Logger._(name));

  /// Resets all global state. For testing only.
  static void reset() {
    _loggers.clear();
    level = Level.info;
    handler = _defaultHandler;
  }

  /// The name of this logger.
  final String name;

  /// Per-logger level override. When non-null, this logger uses this level
  /// instead of [Logger.level].
  Level? loggerLevel;

  Logger._(this.name);

  /// The effective level for this logger: [loggerLevel] if set,
  /// otherwise the global [Logger.level].
  Level get effectiveLevel => loggerLevel ?? Logger.level;

  /// Log a debug-level entry.
  void debug(String message, [List<CharySafe> fields = const []]) =>
      _log(Level.debug, message, fields: fields);

  /// Log an info-level entry.
  void info(String message, [List<CharySafe> fields = const []]) =>
      _log(Level.info, message, fields: fields);

  /// Log a warn-level entry.
  void warn(String message, [List<CharySafe> fields = const []]) =>
      _log(Level.warn, message, fields: fields);

  /// Log an error-level entry.
  void error(
    String message, {
    List<CharySafe>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(Level.error, message,
          fields: fields ?? const [], error: error, stackTrace: stackTrace);

  /// Log a fatal-level entry.
  void fatal(
    String message, {
    List<CharySafe>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(Level.fatal, message,
          fields: fields ?? const [], error: error, stackTrace: stackTrace);

  void _log(
    Level entryLevel,
    String message, {
    List<CharySafe> fields = const [],
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!entryLevel.passes(effectiveLevel)) return;

    // Merge zone context fields with explicit fields.
    // Explicit fields win on key collision.
    final contextFields = LogContext.current;
    final explicitFields = _mergeData(fields);
    final mergedFields = <String, dynamic>{
      ...contextFields,
      ...explicitFields,
    };

    final entry = LogEntry(
      level: entryLevel,
      message: message,
      loggerName: name,
      fields: mergedFields,
      timestamp: DateTime.now().toUtc(),
      error: error,
      stackTrace: stackTrace,
    );

    handler(entry);
  }

  static Map<String, dynamic> _mergeData(List<CharySafe> data) {
    final result = <String, dynamic>{};
    for (final d in data) {
      result.addAll(d.toFields());
    }
    return result;
  }

  static void _defaultHandler(LogEntry entry) {
    // ignore: avoid_print
    print(
        '[${entry.level.name.toUpperCase()}] ${entry.loggerName}: ${entry.message}');
  }
}
