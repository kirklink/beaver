# Beaver — Consumer Guide

Structured, server-side logging with zone-based context propagation and compile-time PII safety.

## Import

```dart
import 'package:beaver/beaver.dart';
```

This re-exports `chary`, so `CharySafe`, `CharyValue`, `CharyValues`, `@Chary()`, and `@CharyField()` are all available.

## Quick Start

```dart
import 'package:beaver/beaver.dart';

void main() {
  Logger.init();
  final log = Logger.get('myApp');
  log.info('started', [CharyValue('port', 8080)]);
}
```

With code generation:

```dart
// order.dart
@Chary()
class Order {
  @CharyField() late String id;
  late String email;           // excluded — not annotated
  @CharyField() late double total;
}

// usage
log.info('order processed', [order.chary.id]);
log.info('order details', [order.chary.all]);
log.info('combined', [order.chary.id, user.chary.name]);
```

---

## CharySafe Types

All log methods and `LogContext.run` accept `List<CharySafe>`.

### CharyValue

```dart
CharyValue(String key, dynamic value)
```

A single safe key-value pair:

```dart
log.info('started', [CharyValue('port', 8080)]);
```

### CharyValues

```dart
CharyValues(Map<String, dynamic> fields)
```

Multiple safe key-value pairs:

```dart
log.info('request', [CharyValues({'method': 'GET', 'path': '/api'})]);
```

### Generated Accessors

With `@Chary()` and `@CharyField()` annotations + `chary_builder`:

```dart
order.chary.id     // CharyValue('id', 'abc-123')
order.chary.total  // CharyValue('total', 42.50)
order.chary.all    // CharyValues({'id': 'abc-123', 'total': 42.50})
```

---

## Level

Severity levels, lowest to highest:

| Level | Use for |
|-------|---------|
| `Level.debug` | Verbose diagnostic output |
| `Level.info` | Normal operational events |
| `Level.warn` | Unexpected but recoverable situations |
| `Level.error` | Failures that need attention |
| `Level.fatal` | Unrecoverable errors, shutdown |

```dart
/// Returns true if this level is at or above [threshold].
bool passes(Level threshold)
```

---

## LogEntry

Immutable data class representing a single log event.

```dart
const LogEntry({
  required Level level,
  required String message,
  required String loggerName,
  Map<String, dynamic> fields = const {},
  required DateTime timestamp,
  Object? error,
  StackTrace? stackTrace,
})
```

| Field | Type | Description |
|-------|------|-------------|
| `level` | `Level` | Severity |
| `message` | `String` | Human-readable message |
| `loggerName` | `String` | Name of the logger that created this entry |
| `fields` | `Map<String, dynamic>` | Structured data (context + explicit, merged from CharySafe) |
| `timestamp` | `DateTime` | UTC timestamp |
| `error` | `Object?` | Optional error object |
| `stackTrace` | `StackTrace?` | Optional stack trace |

You rarely construct `LogEntry` directly — the `Logger` creates them.

### copyWith

```dart
LogEntry copyWith({
  Level? level,
  String? message,
  String? loggerName,
  Map<String, dynamic>? fields,
  DateTime? timestamp,
  Object? error,
  StackTrace? stackTrace,
})
```

Returns a copy with the given fields replaced. Used internally by `scrub()`.

---

## Logger

Named, level-filtered logger. Singleton per name.

### Getting a Logger

```dart
static Logger get(String name)
```

Same name always returns the same instance:

```dart
final log = Logger.get('myApp.server');
```

### Setup

Call once at startup:

```dart
/// Configures logging for the common case.
/// Pretty console output by default; JSON when [json] is true.
static void init({
  bool json = false,
  bool color = true,
  Level level = Level.info,
})
```

```dart
// Development (default)
Logger.init();

// Production
Logger.init(json: true, level: Level.warn);

// Debug with no color
Logger.init(level: Level.debug, color: false);
```

For custom setups, configure the handler directly:

```dart
/// Global minimum level. Default: Level.info
static Level level

/// Global handler. Default: prints to console.
static LogHandler handler
```

```dart
Logger.level = Level.info;
Logger.handler = makeHandler(jsonFormatter(), stderrSink());
```

### Per-Logger Level Override

```dart
/// Override the global level for this logger only. Set to null to revert.
Level? loggerLevel

/// The effective level: loggerLevel ?? Logger.level
Level get effectiveLevel
```

```dart
final dbLog = Logger.get('myApp.db');
dbLog.loggerLevel = Level.warn; // silence chatty DB logs
```

### Log Methods

```dart
void debug(String message, [List<CharySafe> fields = const []])
void info(String message, [List<CharySafe> fields = const []])
void warn(String message, [List<CharySafe> fields = const []])
void error(String message, {List<CharySafe>? fields, Object? error, StackTrace? stackTrace})
void fatal(String message, {List<CharySafe>? fields, Object? error, StackTrace? stackTrace})
```

`debug`, `info`, and `warn` take an optional positional `List<CharySafe>`.
`error` and `fatal` use named parameters so you can pass an error without fields:

```dart
log.info('order processed', [order.chary.id, order.chary.total]);
log.error('payment failed', error: exception, stackTrace: stackTrace);
log.error('payment failed', fields: [order.chary.id], error: exception);
```

### Reset (Testing)

```dart
/// Clears all loggers and restores global defaults. For testing only.
static void reset()
```

---

## LogHandler

```dart
typedef LogHandler = void Function(LogEntry entry)
```

The function that receives every `LogEntry` that passes the level filter. Typically created with `makeHandler`.

---

## Formatter

```dart
typedef Formatter = String Function(LogEntry entry)
```

Converts a `LogEntry` to a string.

### jsonFormatter

```dart
Formatter jsonFormatter()
```

One JSON object per line. All fields are top-level keys:

```json
{"timestamp":"2025-01-15T10:30:00.000Z","level":"INFO","logger":"myApp","message":"started","port":8080}
```

Error and stack trace are included as `"error"` and `"stackTrace"` keys when present.

### prettyFormatter

```dart
Formatter prettyFormatter({bool color = true})
```

Human-readable output with optional ANSI colors:

```
10:30:00.000 INFO  myApp: started {port=8080}
```

Colors by level: debug=gray, info=blue, warn=yellow, error=red, fatal=red background.

---

## LogSink

```dart
typedef LogSink = void Function(String line)
```

Writes a formatted string to a destination.

### Built-in Sinks

```dart
LogSink stdoutSink()
LogSink stderrSink()
LogSink callbackSink(void Function(String) callback)
```

`callbackSink` is useful for testing:

```dart
final lines = <String>[];
Logger.handler = makeHandler(jsonFormatter(), callbackSink(lines.add));
```

### makeHandler

```dart
LogHandler makeHandler(Formatter formatter, LogSink sink)
```

Composes a formatter and sink into a handler:

```dart
Logger.handler = makeHandler(jsonFormatter(), stdoutSink());
```

---

## LogContext

Zone-based log context for automatic field propagation.

### run

```dart
static R run<R>(List<CharySafe> fields, R Function() body)
```

Runs `body` in a zone where `fields` are automatically attached to every log entry. Works across `await` boundaries.

```dart
await LogContext.run([CharyValue('requestId', 'abc-123')], () async {
  log.info('processing');     // fields include requestId
  await someAsyncWork();
  log.info('done');           // still has requestId
});
```

### current

```dart
static Map<String, dynamic> get current
```

Returns the context fields for the current zone, or an empty map if none.

### Nesting

Nested `run` calls merge fields. Child fields override parent on collision:

```dart
LogContext.run([CharyValues({'service': 'api', 'env': 'prod'})], () {
  LogContext.run([CharyValues({'requestId': 'abc', 'env': 'test'})], () {
    // current: {service: 'api', env: 'test', requestId: 'abc'}
  });
});
```

### Field Merge Order

When a log method is called:
1. Read zone context fields (`LogContext.current`)
2. Merge with explicit fields passed to the log call
3. Explicit fields override context fields on key collision

```dart
LogContext.run([CharyValue('source', 'context')], () {
  log.info('msg', [CharyValue('source', 'explicit')]);
  // entry.fields['source'] == 'explicit'
});
```

---

## PII Scrubbing

Key-based redaction of sensitive field values. Defense in depth — works alongside Chary's compile-time safety.

### scrub

```dart
LogHandler scrub({
  required Set<String> keys,
  required LogHandler handler,
})
```

Wraps a handler to redact field values for the specified keys. Keys and message strings are left intact — only values are replaced with `[REDACTED]`.

```dart
Logger.handler = scrub(
  keys: {'email', 'password', 'ssn'},
  handler: makeHandler(jsonFormatter(), stdoutSink()),
);

log.info('user created', [CharyValues({'email': 'a@b.com', 'role': 'admin'})]);
// {"email":"[REDACTED]","role":"admin",...}
```

### redacted

```dart
const redacted = '[REDACTED]'
```

The replacement string. Exposed so you can test against it:

```dart
expect(entry.fields['email'], redacted);
```

---

## Complete Example

```dart
import 'dart:io';
import 'package:beaver/beaver.dart';

final _log = Logger.get('myApp.server');

Future<void> main() async {
  // Configure logging
  final isDev = Platform.environment['ENV'] != 'production';
  Logger.init(
    json: !isDev,
    level: isDev ? Level.debug : Level.info,
  );

  _log.info('server starting', [CharyValue('port', 8080)]);

  // Simulate request handling
  await handleRequest('GET', '/api/items', 'req-001');
  await handleRequest('POST', '/api/orders', 'req-002');

  _log.info('server stopping');
}

Future<void> handleRequest(String method, String path, String requestId) async {
  await LogContext.run([CharyValue('requestId', requestId)], () async {
    final log = Logger.get('myApp.handler');
    log.info('request started', [CharyValues({'method': method, 'path': path})]);

    try {
      // Simulate work
      await Future.delayed(Duration(milliseconds: 50));
      log.info('request completed', [CharyValue('status', 200)]);
    } catch (e, stack) {
      log.error('request failed',
          fields: [CharyValues({'method': method, 'path': path})],
          error: e,
          stackTrace: stack);
    }
  });
}
```

**Dev output** (prettyFormatter):

```
10:30:00.000 INFO  myApp.server: server starting {port=8080}
10:30:00.001 INFO  myApp.handler: request started {requestId=req-001, method=GET, path=/api/items}
10:30:00.052 INFO  myApp.handler: request completed {requestId=req-001, status=200}
10:30:00.053 INFO  myApp.handler: request started {requestId=req-002, method=POST, path=/api/orders}
10:30:00.104 INFO  myApp.handler: request completed {requestId=req-002, status=200}
10:30:00.105 INFO  myApp.server: server stopping
```

**Production output** (jsonFormatter):

```json
{"timestamp":"2025-01-15T10:30:00.000Z","level":"INFO","logger":"myApp.server","message":"server starting","port":8080}
{"timestamp":"2025-01-15T10:30:00.001Z","level":"INFO","logger":"myApp.handler","message":"request started","requestId":"req-001","method":"GET","path":"/api/items"}
{"timestamp":"2025-01-15T10:30:00.052Z","level":"INFO","logger":"myApp.handler","message":"request completed","requestId":"req-001","status":200}
```
