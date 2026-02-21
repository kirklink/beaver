# Beaver

A little logger for Dart.

## What

Structured, server-side logging with zone-based context propagation and compile-time PII safety via `chary`.

## Why

- **Type-safe fields.** Log entries accept `CharySafe` — only fields explicitly marked `@CharyField()` can be logged. No freeform maps, no accidental PII.
- **Zone-based context.** Wrap a request in `LogContext.run([order.chary.id], ...)` and every log entry inside — across async boundaries — carries that field automatically.
- **Functional composition.** Formatters and sinks are plain functions, not class hierarchies. Compose them with `makeHandler`.
- **Five levels.** `debug`, `info`, `warn`, `error`, `fatal`. Not nine.

## Features

- Named singleton loggers with global + per-logger level filtering
- JSON formatter for cloud log pipelines (Datadog, CloudWatch, ELK)
- Pretty console formatter with ANSI colors for development
- Pluggable sinks (stdout, stderr, callback)
- Zone-based `LogContext` for automatic field propagation through async code
- Key-based PII scrubbing via `scrub()` handler wrapper (defense in depth)

## Quick Start

```dart
import 'package:beaver/beaver.dart';

void main() {
  Logger.init(); // pretty console output; use Logger.init(json: true) for production

  final log = Logger.get('myApp');
  log.info('started', [CharyValue('port', 8080)]);

  // Context propagation
  LogContext.run([CharyValue('requestId', 'abc-123')], () {
    log.info('handling request'); // requestId appears automatically
  });
}
```

With code generation:

```dart
log.info('order processed', [order.chary.id]);
log.info('order details', [order.chary.all]);
```

## Docs

- [CLAUDE.md](CLAUDE.md) — for AI modifying this package
- [docs/guide.md](docs/guide.md) — for AI using this package

## Status

v2.0.0 — Core, formatters, sinks, context propagation, PII scrubbing, Chary integration. 71 tests.
