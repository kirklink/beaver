import 'dart:convert';

import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

LogEntry _entry({
  Level level = Level.info,
  String message = 'test message',
  String loggerName = 'test',
  Map<String, dynamic> fields = const {},
  DateTime? timestamp,
  Object? error,
  StackTrace? stackTrace,
}) {
  return LogEntry(
    level: level,
    message: message,
    loggerName: loggerName,
    fields: fields,
    timestamp: timestamp ?? DateTime.utc(2025, 1, 15, 10, 30, 0),
    error: error,
    stackTrace: stackTrace,
  );
}

void main() {
  group('jsonFormatter', () {
    final format = jsonFormatter();

    test('produces valid JSON', () {
      final line = format(_entry());
      expect(() => jsonDecode(line), returnsNormally);
    });

    test('includes core keys', () {
      final map = jsonDecode(format(_entry())) as Map<String, dynamic>;
      expect(map['timestamp'], '2025-01-15T10:30:00.000Z');
      expect(map['level'], 'INFO');
      expect(map['logger'], 'test');
      expect(map['message'], 'test message');
    });

    test('includes fields as top-level keys', () {
      final map = jsonDecode(format(_entry(
        fields: {'orderId': 42, 'status': 'paid'},
      ))) as Map<String, dynamic>;
      expect(map['orderId'], 42);
      expect(map['status'], 'paid');
    });

    test('includes error when present', () {
      final map = jsonDecode(format(_entry(
        error: FormatException('bad input'),
      ))) as Map<String, dynamic>;
      expect(map['error'], contains('bad input'));
    });

    test('omits error when null', () {
      final map = jsonDecode(format(_entry())) as Map<String, dynamic>;
      expect(map.containsKey('error'), isFalse);
    });

    test('includes stackTrace when present', () {
      final stack = StackTrace.current;
      final map = jsonDecode(format(_entry(
        stackTrace: stack,
      ))) as Map<String, dynamic>;
      expect(map['stackTrace'], isNotEmpty);
    });

    test('omits stackTrace when null', () {
      final map = jsonDecode(format(_entry())) as Map<String, dynamic>;
      expect(map.containsKey('stackTrace'), isFalse);
    });

    test('level names are uppercase', () {
      for (final level in Level.values) {
        final map =
            jsonDecode(format(_entry(level: level))) as Map<String, dynamic>;
        expect(map['level'], level.name.toUpperCase());
      }
    });
  });

  group('prettyFormatter', () {
    test('includes level and logger name', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry(level: Level.warn, loggerName: 'myApp'));
      expect(line, contains('WARN'));
      expect(line, contains('myApp'));
    });

    test('includes message', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry(message: 'hello world'));
      expect(line, contains('hello world'));
    });

    test('includes formatted time', () {
      final format = prettyFormatter(color: false);
      final line =
          format(_entry(timestamp: DateTime.utc(2025, 1, 15, 9, 5, 3, 42)));
      expect(line, contains('09:05:03.042'));
    });

    test('includes fields as key=value pairs', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry(fields: {'port': 8080}));
      expect(line, contains('{port=8080}'));
    });

    test('omits fields block when empty', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry());
      expect(line, isNot(contains('{')));
    });

    test('includes error when present', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry(error: StateError('boom')));
      expect(line, contains('error:'));
      expect(line, contains('boom'));
    });

    test('color=false omits ANSI codes', () {
      final format = prettyFormatter(color: false);
      final line = format(_entry());
      expect(line, isNot(contains('\x1B[')));
    });

    test('color=true includes ANSI codes', () {
      final format = prettyFormatter(color: true);
      final line = format(_entry());
      expect(line, contains('\x1B['));
    });
  });
}
