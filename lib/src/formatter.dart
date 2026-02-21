import 'dart:convert';

import 'level.dart';
import 'log_entry.dart';

/// Converts a [LogEntry] into a string for output.
typedef Formatter = String Function(LogEntry entry);

/// Returns a formatter that produces one JSON object per line.
///
/// Output is suitable for cloud log ingestion (Datadog, CloudWatch, ELK).
/// All fields from the entry appear as top-level keys:
///
/// ```json
/// {"timestamp":"2025-01-15T10:30:00.000Z","level":"INFO","logger":"swoop.server","message":"request handled","method":"GET","path":"/api/items","durationMs":42}
/// ```
Formatter jsonFormatter() {
  return (LogEntry entry) {
    final map = <String, dynamic>{
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name.toUpperCase(),
      'logger': entry.loggerName,
      'message': entry.message,
      ...entry.fields,
    };
    if (entry.error != null) {
      map['error'] = entry.error.toString();
    }
    if (entry.stackTrace != null) {
      map['stackTrace'] = entry.stackTrace.toString();
    }
    return jsonEncode(map);
  };
}

/// Returns a formatter that produces colored, human-readable output
/// for development use.
///
/// Format: `HH:mm:ss.SSS LEVEL  loggerName: message {fields}`
///
/// Colors (ANSI):
/// - debug: gray
/// - info: blue
/// - warn: yellow
/// - error: red
/// - fatal: red background, white text
Formatter prettyFormatter({bool color = true}) {
  return (LogEntry entry) {
    final time = _formatTime(entry.timestamp);
    final lvl = entry.level.name.toUpperCase().padRight(5);
    final buffer = StringBuffer();

    if (color) buffer.write(_levelColor(entry.level));
    buffer.write('$time $lvl');
    if (color) buffer.write(_reset);
    buffer.write(' ${entry.loggerName}: ${entry.message}');

    if (entry.fields.isNotEmpty) {
      buffer.write(' ${_formatFields(entry.fields)}');
    }
    if (entry.error != null) {
      buffer.write('\n  error: ${entry.error}');
    }
    if (entry.stackTrace != null) {
      buffer.write('\n${entry.stackTrace}');
    }

    return buffer.toString();
  };
}

String _formatTime(DateTime t) =>
    '${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}.${_pad3(t.millisecond)}';

String _pad2(int n) => n.toString().padLeft(2, '0');
String _pad3(int n) => n.toString().padLeft(3, '0');

String _formatFields(Map<String, dynamic> fields) {
  final pairs = fields.entries.map((e) => '${e.key}=${e.value}').join(', ');
  return '{$pairs}';
}

const _reset = '\x1B[0m';

String _levelColor(Level level) => switch (level) {
      Level.debug => '\x1B[90m', // gray
      Level.info => '\x1B[34m', // blue
      Level.warn => '\x1B[33m', // yellow
      Level.error => '\x1B[31m', // red
      Level.fatal => '\x1B[41;37m', // red bg, white text
    };
