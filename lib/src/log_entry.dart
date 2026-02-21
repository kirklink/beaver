import 'level.dart';

/// A single structured log entry.
///
/// Entries are immutable once created. The [fields] map carries structured
/// data — not just a message string. Zone-inherited context fields from
/// [LogContext] are merged in at creation time by the [Logger].
class LogEntry {
  /// Severity level of this entry.
  final Level level;

  /// Human-readable message.
  final String message;

  /// The logger name that produced this entry.
  final String loggerName;

  /// Structured key-value fields. Includes both explicit fields passed
  /// to the log call and zone-inherited context fields.
  final Map<String, dynamic> fields;

  /// When this entry was created.
  final DateTime timestamp;

  /// Optional error object.
  final Object? error;

  /// Optional stack trace.
  final StackTrace? stackTrace;

  const LogEntry({
    required this.level,
    required this.message,
    required this.loggerName,
    this.fields = const {},
    required this.timestamp,
    this.error,
    this.stackTrace,
  });

  /// Returns a copy with the given fields replaced.
  LogEntry copyWith({
    Level? level,
    String? message,
    String? loggerName,
    Map<String, dynamic>? fields,
    DateTime? timestamp,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return LogEntry(
      level: level ?? this.level,
      message: message ?? this.message,
      loggerName: loggerName ?? this.loggerName,
      fields: fields ?? this.fields,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}
