import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  group('LogEntry', () {
    test('constructor sets all fields', () {
      final ts = DateTime.utc(2025, 1, 15, 10, 30);
      final error = FormatException('bad');
      final stack = StackTrace.current;
      final entry = LogEntry(
        level: Level.error,
        message: 'something broke',
        loggerName: 'test.logger',
        fields: {'key': 'value'},
        timestamp: ts,
        error: error,
        stackTrace: stack,
      );

      expect(entry.level, Level.error);
      expect(entry.message, 'something broke');
      expect(entry.loggerName, 'test.logger');
      expect(entry.fields, {'key': 'value'});
      expect(entry.timestamp, ts);
      expect(entry.error, error);
      expect(entry.stackTrace, stack);
    });

    test('defaults fields to empty map', () {
      final entry = LogEntry(
        level: Level.info,
        message: 'hi',
        loggerName: 'test',
        timestamp: DateTime.now(),
      );

      expect(entry.fields, isEmpty);
    });

    test('defaults error and stackTrace to null', () {
      final entry = LogEntry(
        level: Level.info,
        message: 'hi',
        loggerName: 'test',
        timestamp: DateTime.now(),
      );

      expect(entry.error, isNull);
      expect(entry.stackTrace, isNull);
    });
  });
}
