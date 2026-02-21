import 'dart:async';

import 'package:chary/chary.dart';

/// Zone-based log context for automatic field propagation.
///
/// Attach key-value pairs to a zone, and every log entry within that zone
/// automatically includes those fields — no manual passing required.
///
/// ```dart
/// await LogContext.run([CharyValue('requestId', 'abc-123')], () async {
///   log.info('processing'); // fields automatically include requestId
///   await someAsyncWork();
///   log.info('done');       // still has requestId
/// });
/// ```
class LogContext {
  static const _zoneKey = #beaver.logContext;

  /// Returns the current zone's context fields, or empty map if none.
  static Map<String, dynamic> get current {
    final ctx = Zone.current[_zoneKey];
    if (ctx is Map<String, dynamic>) return ctx;
    return const {};
  }

  /// Runs [body] in a new zone with [fields] added to the log context.
  ///
  /// Fields are merged with any parent zone's context. Child fields
  /// override parent fields on key collision.
  static R run<R>(List<CharySafe> fields, R Function() body) {
    final newFields = <String, dynamic>{};
    for (final d in fields) {
      newFields.addAll(d.toFields());
    }
    final merged = {...current, ...newFields};
    return runZoned(body, zoneValues: {_zoneKey: merged});
  }
}
