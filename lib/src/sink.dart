import 'dart:io' as io;

import 'formatter.dart';
import 'log_entry.dart';
import 'logger.dart';

/// Writes a formatted log line to a destination.
typedef LogSink = void Function(String line);

/// Returns a [LogHandler] that formats entries and sends them to [sink].
///
/// This is the primary way to wire up logging:
/// ```dart
/// Logger.handler = makeHandler(jsonFormatter(), stdoutSink());
/// ```
LogHandler makeHandler(Formatter formatter, LogSink sink) {
  return (LogEntry entry) {
    sink(formatter(entry));
  };
}

/// A sink that writes to stdout.
LogSink stdoutSink() => io.stdout.writeln;

/// A sink that writes to stderr.
LogSink stderrSink() => io.stderr.writeln;

/// A sink that delegates to [callback].
///
/// Useful for testing — capture log output in a list:
/// ```dart
/// final lines = <String>[];
/// Logger.handler = makeHandler(jsonFormatter(), callbackSink(lines.add));
/// ```
LogSink callbackSink(void Function(String) callback) => callback;
