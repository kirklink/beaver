# Beaver — Contributor Guide

## Commands

```bash
dart test --reporter github 2>/dev/null          # all tests
dart test --reporter github 2>/dev/null | tail -1 # summary only
dart analyze                                      # static analysis
```

## Package Structure

```
lib/
  beaver.dart           # barrel export (re-exports chary)
  src/
    level.dart          # Level enum (debug, info, warn, error, fatal)
    log_entry.dart      # LogEntry — immutable structured log data class + copyWith
    logger.dart         # Logger (singleton per name, init(), level filtering, handler dispatch)
                        # LogHandler typedef
    formatter.dart      # Formatter typedef, jsonFormatter(), prettyFormatter()
    sink.dart           # LogSink typedef, makeHandler(), stdoutSink(), stderrSink(), callbackSink()
    context.dart        # LogContext — zone-based field propagation (accepts List<CharySafe>)
    scrub.dart          # scrub() — key-based PII redaction handler wrapper
test/
  level_test.dart       # enum ordering, passes(), compareTo
  log_entry_test.dart   # construction, defaults
  logger_test.dart      # singleton, level filtering, global vs per-logger, init, reset
  formatter_test.dart   # JSON structure, pretty format, color on/off
  sink_test.dart        # makeHandler composition, callbackSink, integration pipeline
  context_test.dart     # zone propagation, nesting, async, merge semantics
  scrub_test.dart       # key redaction, passthrough, context fields, JSON integration
```

## Architecture

### Data Flow

```
log.info('msg', [order.chary.id, CharyValue('status', 200)])
  → Logger._log()
    → level check (passes effectiveLevel?)
    → _mergeData(List<CharySafe>) → Map<String, dynamic>
    → merge LogContext.current + explicit fields (explicit wins)
    → construct LogEntry (immutable, UTC timestamp, fields: Map)
    → call Logger.handler(entry)
      → scrub(entry)? → rebuild entry with redacted fields
      → Formatter(entry) → String
      → LogSink(string) → stdout/stderr/callback
```

All synchronous. No buffering, no async output, no queues.

### Key Patterns

- **Chary integration**: Logger methods accept `List<CharySafe>` instead of `Map<String, dynamic>`. The `_mergeData()` helper converts to a flat map. `LogEntry.fields` stays `Map<String, dynamic>` — formatters and sinks see the same type as v1.
- **Singleton loggers**: `Logger.get(name)` caches in a static `Map<String, Logger>`. Same name = same instance.
- **Global + per-logger levels**: `Logger.level` is the global threshold. `logger.loggerLevel` overrides it for one logger. `effectiveLevel` resolves this.
- **Functional composition**: `Formatter` and `LogSink` are typedefs (`String Function(LogEntry)` and `void Function(String)`). `makeHandler` glues them into a `LogHandler`.
- **Zone-based context**: `LogContext.run()` accepts `List<CharySafe>`, converts to Map, creates a child zone with `#beaver.logContext` zone value. `LogContext.current` reads from `Zone.current`. Nested runs merge with parent fields.
- **Re-export**: `beaver.dart` re-exports `package:chary/chary.dart` so consumers only need `import 'package:beaver/beaver.dart'`.

### Design Decisions

- **`List<CharySafe>` not `Map<String, dynamic>`**: Compile-time PII safety. Only fields marked `@CharyField()` can reach logs via generated accessors. `CharyValue` and `CharyValues` are the escape hatches for non-generated data.
- **`LogEntry.fields` stays `Map<String, dynamic>`**: Internal representation unchanged. Formatters, sinks, and scrub() see the same flat map. The CharySafe→Map conversion happens once in `_log()`.
- **`LogSink` not `Sink`**: Avoids shadowing `dart:core`'s `Sink<T>`.
- **No `off`/`all` sentinel levels**: Set level to `fatal` to effectively silence. Fewer concepts.
- **Explicit fields override context fields**: More specific wins on key collision.
- **UTC timestamps**: `DateTime.now().toUtc()` — no timezone ambiguity in log output.
- **`Logger.init()`**: Convenience for the 90% case. `init()` = pretty to stdout. `init(json: true)` = JSON to stdout. Power users bypass with `Logger.handler = makeHandler(...)`.
- **Named params on `error`/`fatal`**: `fields`, `error`, `stackTrace` are named — no positional guessing. `debug`/`info`/`warn` keep positional fields for the common case.
- **`Logger.reset()`**: Exists for testing. Clears the logger cache and restores defaults.
- **`scrub()` as defense in depth**: Still works on the final `Map<String, dynamic>` in LogEntry. Catches edge cases even with CharySafe in place.

### Integration Points

- **Swoop**: Wrap `handleRequest()` in `LogContext.run([CharyValue('requestId', ...)])`. Replace `print()` with `Logger.get('swoop.server')`.
- **Envoy**: Use in `onToolCall` callback and `AgentEvent` stream listener.

## Consumer API Reference

See [docs/guide.md](docs/guide.md) for complete API with signatures and examples.

## Status

v2.0.0 — 7 source files, 71 tests. Depends on chary for typed field safety.
