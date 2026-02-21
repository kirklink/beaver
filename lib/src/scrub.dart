import 'log_entry.dart';
import 'logger.dart';

/// The replacement string used for redacted field values.
const redacted = '[REDACTED]';

/// Returns a [LogHandler] that redacts field values for [keys] before
/// passing entries to [handler].
///
/// Only field values are redacted — keys and the message string are
/// left intact so log structure remains searchable.
///
/// ```dart
/// Logger.handler = scrub(
///   keys: {'email', 'password', 'ssn'},
///   handler: makeHandler(jsonFormatter(), stdoutSink()),
/// );
///
/// log.info('user created', {'email': 'a@b.com', 'role': 'admin'});
/// // output: {"email":"[REDACTED]","role":"admin",...}
/// ```
LogHandler scrub({
  required Set<String> keys,
  required LogHandler handler,
}) {
  return (LogEntry entry) {
    if (entry.fields.isEmpty || keys.isEmpty) {
      handler(entry);
      return;
    }

    final scrubbed = <String, dynamic>{};
    for (final e in entry.fields.entries) {
      scrubbed[e.key] = keys.contains(e.key) ? redacted : e.value;
    }

    handler(entry.copyWith(fields: scrubbed));
  };
}
