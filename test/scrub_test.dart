import 'dart:convert';

import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  late List<LogEntry> entries;

  setUp(() {
    Logger.reset();
    entries = [];
  });

  group('scrub', () {
    test('redacts specified field keys', () {
      Logger.handler = scrub(
        keys: {'email', 'password'},
        handler: entries.add,
      );

      Logger.get('t').info(
          'user', [CharyValues({'email': 'a@b.com', 'name': 'Alice'})]);

      final fields = entries.single.fields;
      expect(fields['email'], redacted);
      expect(fields['name'], 'Alice');
    });

    test('leaves non-matching fields intact', () {
      Logger.handler = scrub(
        keys: {'secret'},
        handler: entries.add,
      );

      Logger.get('t').info(
          'data', [CharyValues({'port': 8080, 'host': 'localhost'})]);

      final fields = entries.single.fields;
      expect(fields['port'], 8080);
      expect(fields['host'], 'localhost');
    });

    test('passes through entries with no fields', () {
      Logger.handler = scrub(
        keys: {'email'},
        handler: entries.add,
      );

      Logger.get('t').info('hello');

      expect(entries.single.message, 'hello');
      expect(entries.single.fields, isEmpty);
    });

    test('passes through when keys set is empty', () {
      Logger.handler = scrub(
        keys: {},
        handler: entries.add,
      );

      Logger.get('t').info('data', [CharyValue('email', 'a@b.com')]);

      expect(entries.single.fields['email'], 'a@b.com');
    });

    test('preserves all other entry properties', () {
      Logger.handler = scrub(
        keys: {'secret'},
        handler: entries.add,
      );

      Logger.get('myApp')
          .warn('warning', [CharyValues({'secret': 'x', 'ok': 'y'})]);

      final entry = entries.single;
      expect(entry.level, Level.warn);
      expect(entry.message, 'warning');
      expect(entry.loggerName, 'myApp');
      expect(entry.timestamp.isUtc, isTrue);
    });

    test('works with JSON formatter end-to-end', () {
      final lines = <String>[];
      Logger.handler = scrub(
        keys: {'token'},
        handler: makeHandler(jsonFormatter(), callbackSink(lines.add)),
      );

      Logger.get('t').info(
          'auth', [CharyValues({'token': 'abc123', 'userId': 'u1'})]);

      final map = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(map['token'], redacted);
      expect(map['userId'], 'u1');
    });

    test('works with context fields', () {
      Logger.handler = scrub(
        keys: {'email'},
        handler: entries.add,
      );

      LogContext.run(
          [CharyValues({'email': 'a@b.com', 'requestId': 'r1'})], () {
        Logger.get('t').info('hello');
      });

      final fields = entries.single.fields;
      expect(fields['email'], redacted);
      expect(fields['requestId'], 'r1');
    });

    test('redacts multiple keys', () {
      Logger.handler = scrub(
        keys: {'ssn', 'dob', 'phone'},
        handler: entries.add,
      );

      Logger.get('t').info('profile', [
        CharyValues({
          'ssn': '123-45-6789',
          'dob': '1990-01-01',
          'phone': '555-1234',
          'name': 'Alice',
        })
      ]);

      final fields = entries.single.fields;
      expect(fields['ssn'], redacted);
      expect(fields['dob'], redacted);
      expect(fields['phone'], redacted);
      expect(fields['name'], 'Alice');
    });
  });
}
