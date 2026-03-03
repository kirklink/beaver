---
name: beaver-guide
description: "Beaver consumer API reference — structured logging. TRIGGER when: adding logging to a Dart application, using Logger/LogEntry/Level, configuring log formatters or sinks, setting up zone-based log context with LogContext.run(), implementing PII scrubbing with CharySafe types, or integrating beaver with swoop/envoy."
---

# Beaver — Consumer Guide

Structured, server-side logging with zone-based context propagation and compile-time PII safety via Chary.

**Import:** `package:beaver/beaver.dart` (re-exports chary)

## When to use this skill

Use when writing code that **uses** Beaver for logging. For editing Beaver internals, the contributor guide loads automatically.

## Guide contents

Full reference in [guide.md](guide.md). Key sections:

- **Quick Start** — Logger.init(), Logger.get(), log levels
- **CharySafe Types** — PII-safe field types from Chary
- **Level** — trace, debug, info, warn, error, fatal
- **Logger** — singleton per name, level filtering, handlers
- **LogHandler, Formatter, LogSink** — output pipeline
- **LogContext** — zone-based field propagation
- **PII Scrubbing** — key-based redaction with scrub()
- **Framework Integration** — Swoop/Envoy logging setup
