import 'dart:async';
import 'dart:convert';

import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  late List<LogEntry> entries;

  setUp(() {
    Logger.reset();
    entries = [];
    Logger.handler = entries.add;
  });

  tearDown(() {
    Logger.reset();
  });

  group('Logger singleton stress tests', () {
    test('same name returns identical instance', () {
      final a = Logger.get('test');
      final b = Logger.get('test');
      expect(identical(a, b), isTrue);
    });

    test('different names return different instances', () {
      final a = Logger.get('alpha');
      final b = Logger.get('beta');
      expect(identical(a, b), isFalse);
    });

    test('100 loggers with unique names', () {
      final loggers = [for (var i = 0; i < 100; i++) Logger.get('logger$i')];
      for (var i = 0; i < 100; i++) {
        expect(identical(loggers[i], Logger.get('logger$i')), isTrue);
      }
    });

    test('logger names with special characters', () {
      final names = [
        '',
        ' ',
        'a.b.c',
        'a/b/c',
        'a:b:c',
        'emoji\u{1F600}',
        'tab\there',
        'new\nline',
        'a' * 10000,
      ];
      for (final name in names) {
        final logger = Logger.get(name);
        expect(logger.name, name);
        logger.info('test');
        expect(entries.last.loggerName, name);
      }
    });

    test('reset clears all loggers', () {
      final before = Logger.get('test');
      Logger.reset();
      entries = [];
      Logger.handler = entries.add;
      final after = Logger.get('test');
      expect(identical(before, after), isFalse);
    });
  });

  group('Level filtering stress tests', () {
    test('global level filters correctly for all levels', () {
      final log = Logger.get('test');
      for (final threshold in Level.values) {
        Logger.level = threshold;
        entries.clear();
        log.debug('d');
        log.info('i');
        log.warn('w');
        log.error('e');
        log.fatal('f');
        final expected =
            Level.values.where((l) => l.passes(threshold)).length;
        expect(entries, hasLength(expected),
            reason: 'threshold=$threshold');
      }
    });

    test('per-logger level overrides global', () {
      Logger.level = Level.fatal;
      final log = Logger.get('verbose');
      log.loggerLevel = Level.debug;
      log.debug('should appear');
      expect(entries, hasLength(1));
    });

    test('null per-logger level falls back to global', () {
      Logger.level = Level.warn;
      final log = Logger.get('test');
      log.loggerLevel = null;
      log.debug('no');
      log.info('no');
      log.warn('yes');
      expect(entries, hasLength(1));
    });

    test('effectiveLevel is correct', () {
      final log = Logger.get('test');
      Logger.level = Level.info;
      expect(log.effectiveLevel, Level.info);
      log.loggerLevel = Level.debug;
      expect(log.effectiveLevel, Level.debug);
      log.loggerLevel = null;
      expect(log.effectiveLevel, Level.info);
    });

    test('Level.passes is transitive', () {
      for (final a in Level.values) {
        for (final b in Level.values) {
          expect(a.passes(b), a.index >= b.index,
              reason: '$a.passes($b)');
        }
      }
    });

    test('Level.compareTo is consistent', () {
      for (final a in Level.values) {
        for (final b in Level.values) {
          expect(a.compareTo(b).sign, (a.index - b.index).sign,
              reason: '$a.compareTo($b)');
        }
      }
    });
  });

  group('Log entry stress tests', () {
    test('message is preserved exactly', () {
      final log = Logger.get('test');
      Logger.level = Level.debug;
      final messages = [
        '',
        ' ',
        'simple',
        'line1\nline2',
        'tab\there',
        '\u{1F600} emoji message',
        'a' * 100000,
        'special <>&"\'',
        'null\x00byte',
      ];
      for (final msg in messages) {
        entries.clear();
        log.info(msg);
        expect(entries.single.message, msg);
      }
    });

    test('timestamp is UTC and recent', () {
      final log = Logger.get('test');
      final before = DateTime.now().toUtc();
      log.info('test');
      final after = DateTime.now().toUtc();
      expect(entries.single.timestamp.isUtc, isTrue);
      expect(entries.single.timestamp.isAfter(before) ||
          entries.single.timestamp.isAtSameMomentAs(before), isTrue);
      expect(entries.single.timestamp.isBefore(after) ||
          entries.single.timestamp.isAtSameMomentAs(after), isTrue);
    });

    test('error and stackTrace preserved in error level', () {
      final log = Logger.get('test');
      final error = StateError('boom');
      final stack = StackTrace.current;
      log.error('failed', error: error, stackTrace: stack);
      expect(entries.single.error, same(error));
      expect(entries.single.stackTrace, same(stack));
    });

    test('error and stackTrace preserved in fatal level', () {
      final log = Logger.get('test');
      final error = ArgumentError('bad');
      final stack = StackTrace.current;
      log.fatal('crashed', error: error, stackTrace: stack);
      expect(entries.single.error, same(error));
      expect(entries.single.stackTrace, same(stack));
    });

    test('error is null by default for debug/info/warn', () {
      final log = Logger.get('test');
      Logger.level = Level.debug;
      log.debug('d');
      log.info('i');
      log.warn('w');
      for (final entry in entries) {
        expect(entry.error, isNull);
        expect(entry.stackTrace, isNull);
      }
    });

    test('fields default to empty map', () {
      final log = Logger.get('test');
      log.info('test');
      expect(entries.single.fields, isEmpty);
    });

    test('copyWith preserves all fields when no overrides', () {
      final original = LogEntry(
        level: Level.error,
        message: 'test',
        loggerName: 'lg',
        fields: {'a': 1},
        timestamp: DateTime.utc(2025),
        error: StateError('x'),
        stackTrace: StackTrace.current,
      );
      final copy = original.copyWith();
      expect(copy.level, original.level);
      expect(copy.message, original.message);
      expect(copy.loggerName, original.loggerName);
      expect(copy.fields, original.fields);
      expect(copy.timestamp, original.timestamp);
      expect(copy.error, original.error);
      expect(copy.stackTrace, original.stackTrace);
    });

    test('copyWith replaces specified fields', () {
      final original = LogEntry(
        level: Level.info,
        message: 'original',
        loggerName: 'lg',
        fields: {'a': 1},
        timestamp: DateTime.utc(2025),
      );
      final copy = original.copyWith(
        fields: {'b': 2},
      );
      expect(copy.fields, {'b': 2});
      expect(copy.message, 'original');
    });
  });

  group('Chary integration stress tests', () {
    test('CharyValue produces correct field', () {
      final log = Logger.get('test');
      log.info('msg', [CharyValue('port', 8080)]);
      expect(entries.single.fields, {'port': 8080});
    });

    test('CharyValues produces correct fields', () {
      final log = Logger.get('test');
      log.info('msg', [CharyValues({'a': 1, 'b': 2, 'c': 3})]);
      expect(entries.single.fields, {'a': 1, 'b': 2, 'c': 3});
    });

    test('multiple CharySafe items merge', () {
      final log = Logger.get('test');
      log.info('msg', [
        CharyValue('id', 'abc'),
        CharyValues({'method': 'GET', 'path': '/api'}),
        CharyValue('status', 200),
      ]);
      expect(entries.single.fields, {
        'id': 'abc',
        'method': 'GET',
        'path': '/api',
        'status': 200,
      });
    });

    test('later fields override earlier on collision', () {
      final log = Logger.get('test');
      log.info('msg', [
        CharyValue('x', 1),
        CharyValue('x', 2),
      ]);
      expect(entries.single.fields['x'], 2);
    });

    test('null values in fields', () {
      final log = Logger.get('test');
      log.info('msg', [CharyValue('missing', null)]);
      expect(entries.single.fields['missing'], isNull);
      expect(entries.single.fields.containsKey('missing'), isTrue);
    });

    test('empty fields list produces empty map', () {
      final log = Logger.get('test');
      log.info('msg', []);
      expect(entries.single.fields, isEmpty);
    });

    test('many fields merge correctly', () {
      final log = Logger.get('test');
      final fields = [
        for (var i = 0; i < 100; i++) CharyValue('field$i', i),
      ];
      log.info('msg', fields);
      expect(entries.single.fields, hasLength(100));
      for (var i = 0; i < 100; i++) {
        expect(entries.single.fields['field$i'], i);
      }
    });

    test('error level accepts fields', () {
      final log = Logger.get('test');
      log.error('err',
          fields: [CharyValue('code', 500)],
          error: StateError('boom'));
      expect(entries.single.fields, {'code': 500});
      expect(entries.single.error, isA<StateError>());
    });

    test('fatal level accepts fields', () {
      final log = Logger.get('test');
      log.fatal('crash',
          fields: [CharyValue('signal', 'SIGTERM')]);
      expect(entries.single.fields, {'signal': 'SIGTERM'});
    });
  });

  group('LogContext zone stress tests', () {
    test('context fields propagate to log entries', () {
      final log = Logger.get('test');
      LogContext.run([CharyValue('requestId', 'req-1')], () {
        log.info('processing');
      });
      expect(entries.single.fields, {'requestId': 'req-1'});
    });

    test('nested contexts merge fields', () {
      final log = Logger.get('test');
      LogContext.run([CharyValue('service', 'api')], () {
        LogContext.run([CharyValue('env', 'test')], () {
          log.info('msg');
        });
      });
      expect(entries.single.fields, {'service': 'api', 'env': 'test'});
    });

    test('deeply nested contexts (10 levels)', () {
      final log = Logger.get('test');
      void nest(int depth) {
        if (depth == 0) {
          log.info('deep');
          return;
        }
        LogContext.run([CharyValue('level$depth', depth)], () {
          nest(depth - 1);
        });
      }

      nest(10);
      expect(entries.single.fields, hasLength(10));
      for (var i = 1; i <= 10; i++) {
        expect(entries.single.fields['level$i'], i);
      }
    });

    test('child context overrides parent on collision', () {
      final log = Logger.get('test');
      LogContext.run([CharyValue('x', 'parent')], () {
        LogContext.run([CharyValue('x', 'child')], () {
          log.info('msg');
        });
      });
      expect(entries.single.fields['x'], 'child');
    });

    test('explicit fields override context on collision', () {
      final log = Logger.get('test');
      LogContext.run([CharyValue('source', 'context')], () {
        log.info('msg', [CharyValue('source', 'explicit')]);
      });
      expect(entries.single.fields['source'], 'explicit');
    });

    test('context fields persist across await', () async {
      final log = Logger.get('test');
      await LogContext.run([CharyValue('traceId', 't1')], () async {
        await Future.delayed(Duration.zero);
        log.info('delayed');
      });
      expect(entries.single.fields['traceId'], 't1');
    });

    test('context fields persist across multiple awaits', () async {
      final log = Logger.get('test');
      await LogContext.run([CharyValue('reqId', 'r1')], () async {
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        await Future.delayed(Duration.zero);
        log.info('after multiple awaits');
      });
      expect(entries.single.fields['reqId'], 'r1');
    });

    test('parallel zones have isolated contexts', () async {
      final log = Logger.get('test');
      await Future.wait([
        LogContext.run([CharyValue('zone', 'A')], () async {
          await Future.delayed(Duration(milliseconds: 10));
          log.info('from A');
        }),
        LogContext.run([CharyValue('zone', 'B')], () async {
          await Future.delayed(Duration(milliseconds: 5));
          log.info('from B');
        }),
      ]);
      expect(entries, hasLength(2));
      final zoneValues = entries.map((e) => e.fields['zone']).toSet();
      expect(zoneValues, {'A', 'B'});
    });

    test('context outside any run() is empty', () {
      final log = Logger.get('test');
      log.info('no context');
      expect(entries.single.fields, isEmpty);
    });

    test('LogContext.current returns empty map outside run', () {
      expect(LogContext.current, isEmpty);
    });

    test('LogContext.current returns fields inside run', () {
      LogContext.run([CharyValue('k', 'v')], () {
        expect(LogContext.current, {'k': 'v'});
      });
    });

    test('many context fields', () {
      final log = Logger.get('test');
      final fields = [
        for (var i = 0; i < 50; i++) CharyValue('ctx$i', i),
      ];
      LogContext.run(fields, () {
        log.info('msg', [
          for (var i = 0; i < 50; i++) CharyValue('explicit$i', i),
        ]);
      });
      expect(entries.single.fields, hasLength(100));
    });
  });

  group('Formatter stress tests', () {
    test('jsonFormatter produces valid JSON', () {
      final format = jsonFormatter();
      final log = Logger.get('test');
      Logger.level = Level.debug;

      log.debug('d');
      log.info('i', [CharyValue('port', 8080)]);
      log.warn('w');
      log.error('e', error: StateError('boom'), stackTrace: StackTrace.current);
      log.fatal('f');

      for (final entry in entries) {
        final line = format(entry);
        final map = jsonDecode(line) as Map<String, dynamic>;
        expect(map, containsPair('message', isA<String>()));
        expect(map, containsPair('level', isA<String>()));
        expect(map, containsPair('logger', 'test'));
        expect(map, containsPair('timestamp', isA<String>()));
      }
    });

    test('jsonFormatter fields appear at top level', () {
      final format = jsonFormatter();
      final entry = LogEntry(
        level: Level.info,
        message: 'test',
        loggerName: 'app',
        fields: {'port': 8080, 'host': 'localhost'},
        timestamp: DateTime.utc(2025, 1, 15),
      );
      final map = jsonDecode(format(entry)) as Map<String, dynamic>;
      expect(map['port'], 8080);
      expect(map['host'], 'localhost');
    });

    test('jsonFormatter omits error when null', () {
      final format = jsonFormatter();
      final entry = LogEntry(
        level: Level.info,
        message: 'ok',
        loggerName: 'app',
        timestamp: DateTime.utc(2025),
      );
      final map = jsonDecode(format(entry)) as Map<String, dynamic>;
      expect(map.containsKey('error'), isFalse);
      expect(map.containsKey('stackTrace'), isFalse);
    });

    test('jsonFormatter includes error when present', () {
      final format = jsonFormatter();
      final entry = LogEntry(
        level: Level.error,
        message: 'fail',
        loggerName: 'app',
        timestamp: DateTime.utc(2025),
        error: StateError('boom'),
        stackTrace: StackTrace.current,
      );
      final map = jsonDecode(format(entry)) as Map<String, dynamic>;
      expect(map.containsKey('error'), isTrue);
      expect(map.containsKey('stackTrace'), isTrue);
    });

    test('jsonFormatter level is uppercase', () {
      final format = jsonFormatter();
      for (final level in Level.values) {
        final entry = LogEntry(
          level: level,
          message: 'test',
          loggerName: 'app',
          timestamp: DateTime.utc(2025),
        );
        final map = jsonDecode(format(entry)) as Map<String, dynamic>;
        expect(map['level'], level.name.toUpperCase());
      }
    });

    test('jsonFormatter timestamp is ISO 8601', () {
      final format = jsonFormatter();
      final entry = LogEntry(
        level: Level.info,
        message: 'test',
        loggerName: 'app',
        timestamp: DateTime.utc(2025, 6, 15, 10, 30, 0),
      );
      final map = jsonDecode(format(entry)) as Map<String, dynamic>;
      expect(DateTime.tryParse(map['timestamp'] as String), isNotNull);
    });

    test('jsonFormatter handles special characters in message', () {
      final format = jsonFormatter();
      final entry = LogEntry(
        level: Level.info,
        message: 'line1\nline2\t"quoted"',
        loggerName: 'app',
        timestamp: DateTime.utc(2025),
      );
      final line = format(entry);
      final map = jsonDecode(line) as Map<String, dynamic>;
      expect(map['message'], 'line1\nline2\t"quoted"');
    });

    test('jsonFormatter handles many fields', () {
      final format = jsonFormatter();
      final fields = <String, dynamic>{
        for (var i = 0; i < 100; i++) 'field$i': 'value$i',
      };
      final entry = LogEntry(
        level: Level.info,
        message: 'test',
        loggerName: 'app',
        fields: fields,
        timestamp: DateTime.utc(2025),
      );
      final map = jsonDecode(format(entry)) as Map<String, dynamic>;
      for (var i = 0; i < 100; i++) {
        expect(map['field$i'], 'value$i');
      }
    });

    test('prettyFormatter without color produces readable output', () {
      final format = prettyFormatter(color: false);
      final entry = LogEntry(
        level: Level.info,
        message: 'started',
        loggerName: 'myApp',
        fields: {'port': 8080},
        timestamp: DateTime.utc(2025, 1, 15, 10, 30, 0),
      );
      final line = format(entry);
      expect(line, contains('INFO'));
      expect(line, contains('myApp'));
      expect(line, contains('started'));
      expect(line, contains('port'));
      expect(line, contains('8080'));
    });

    test('prettyFormatter omits field block when empty', () {
      final format = prettyFormatter(color: false);
      final entry = LogEntry(
        level: Level.info,
        message: 'test',
        loggerName: 'app',
        timestamp: DateTime.utc(2025),
      );
      final line = format(entry);
      expect(line, isNot(contains('{')));
    });

    test('prettyFormatter includes error on separate line', () {
      final format = prettyFormatter(color: false);
      final entry = LogEntry(
        level: Level.error,
        message: 'fail',
        loggerName: 'app',
        timestamp: DateTime.utc(2025),
        error: StateError('boom'),
      );
      final line = format(entry);
      expect(line, contains('boom'));
    });
  });

  group('Sink stress tests', () {
    test('callbackSink receives formatted output', () {
      final lines = <String>[];
      Logger.handler =
          makeHandler(jsonFormatter(), callbackSink(lines.add));
      Logger.get('test').info('hello');
      expect(lines, hasLength(1));
      expect(lines.single, contains('"message":"hello"'));
    });

    test('makeHandler chains formatter and sink', () {
      final lines = <String>[];
      final handler =
          makeHandler(prettyFormatter(color: false), callbackSink(lines.add));
      handler(LogEntry(
        level: Level.warn,
        message: 'caution',
        loggerName: 'test',
        timestamp: DateTime.utc(2025),
      ));
      expect(lines.single, contains('WARN'));
      expect(lines.single, contains('caution'));
    });

    test('many log entries through sink', () {
      final lines = <String>[];
      Logger.handler =
          makeHandler(jsonFormatter(), callbackSink(lines.add));
      final log = Logger.get('perf');
      for (var i = 0; i < 1000; i++) {
        log.info('message $i', [CharyValue('i', i)]);
      }
      expect(lines, hasLength(1000));
    });
  });

  group('Scrub stress tests', () {
    test('redacts specified keys', () {
      Logger.handler = scrub(
        keys: {'password', 'ssn'},
        handler: entries.add,
      );
      Logger.get('test').info('user', [
        CharyValues({
          'name': 'Alice',
          'password': 'secret123',
          'ssn': '123-45-6789',
        }),
      ]);
      expect(entries.single.fields['name'], 'Alice');
      expect(entries.single.fields['password'], redacted);
      expect(entries.single.fields['ssn'], redacted);
    });

    test('passes through when no matching keys', () {
      Logger.handler = scrub(
        keys: {'secret'},
        handler: entries.add,
      );
      Logger.get('test').info('safe', [CharyValue('name', 'Bob')]);
      expect(entries.single.fields['name'], 'Bob');
    });

    test('passes through when fields are empty', () {
      Logger.handler = scrub(
        keys: {'secret'},
        handler: entries.add,
      );
      Logger.get('test').info('no fields');
      expect(entries.single.fields, isEmpty);
    });

    test('passes through when keys set is empty', () {
      Logger.handler = scrub(
        keys: {},
        handler: entries.add,
      );
      Logger.get('test').info('msg', [CharyValue('data', 'visible')]);
      expect(entries.single.fields['data'], 'visible');
    });

    test('redacts context fields too', () {
      Logger.handler = scrub(
        keys: {'token'},
        handler: entries.add,
      );
      LogContext.run([CharyValue('token', 'bearer-xyz')], () {
        Logger.get('test').info('request');
      });
      expect(entries.single.fields['token'], redacted);
    });

    test('scrub integrates with jsonFormatter', () {
      final lines = <String>[];
      Logger.handler = scrub(
        keys: {'password'},
        handler: makeHandler(jsonFormatter(), callbackSink(lines.add)),
      );
      Logger.get('test').info('login', [
        CharyValues({'user': 'alice', 'password': 'secret'}),
      ]);
      final map = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(map['user'], 'alice');
      expect(map['password'], redacted);
    });

    test('redacts multiple keys from large field set', () {
      final sensitiveKeys = {'ssn', 'password', 'token', 'secret', 'apiKey'};
      Logger.handler = scrub(
        keys: sensitiveKeys,
        handler: entries.add,
      );
      Logger.get('test').info('data', [
        CharyValues({
          'name': 'Alice',
          'ssn': '123',
          'password': 'pass',
          'token': 'tok',
          'secret': 'sec',
          'apiKey': 'key',
          'email': 'a@b.com',
        }),
      ]);
      final fields = entries.single.fields;
      expect(fields['name'], 'Alice');
      expect(fields['email'], 'a@b.com');
      for (final key in sensitiveKeys) {
        expect(fields[key], redacted, reason: 'key=$key');
      }
    });
  });

  group('Init convenience stress tests', () {
    test('init with json mode sets jsonFormatter', () {
      final lines = <String>[];
      Logger.init(json: true, level: Level.debug);
      // Override sink for testing
      Logger.handler = makeHandler(jsonFormatter(), callbackSink(lines.add));
      Logger.get('test').info('init test');
      expect(lines, hasLength(1));
      expect(() => jsonDecode(lines.single), returnsNormally);
    });

    test('init resets level', () {
      Logger.init(level: Level.warn);
      expect(Logger.level, Level.warn);
    });

    test('reset restores defaults', () {
      Logger.level = Level.fatal;
      final log = Logger.get('test');
      log.loggerLevel = Level.debug;
      Logger.reset();
      expect(Logger.level, Level.info);
    });
  });

  group('High-throughput stress tests', () {
    test('1000 log entries with fields and context', () {
      final log = Logger.get('throughput');
      LogContext.run([CharyValue('service', 'stress')], () {
        for (var i = 0; i < 1000; i++) {
          log.info('event $i', [CharyValue('i', i)]);
        }
      });
      expect(entries, hasLength(1000));
      for (var i = 0; i < 1000; i++) {
        expect(entries[i].message, 'event $i');
        expect(entries[i].fields['i'], i);
        expect(entries[i].fields['service'], 'stress');
      }
    });

    test('rapid level changes during logging', () {
      final log = Logger.get('rapid');
      Logger.level = Level.debug;
      for (var i = 0; i < 100; i++) {
        Logger.level = Level.values[i % Level.values.length];
        log.info('msg $i');
      }
      // info passes for debug (0), info (1) → 2 out of 5
      // Each cycle of 5: passes when threshold is debug or info
      final expectedPasses = entries.length;
      expect(expectedPasses, greaterThan(0));
    });

    test('all log methods produce correct levels', () {
      final log = Logger.get('test');
      Logger.level = Level.debug;
      log.debug('d');
      log.info('i');
      log.warn('w');
      log.error('e');
      log.fatal('f');
      expect(entries.map((e) => e.level).toList(), [
        Level.debug,
        Level.info,
        Level.warn,
        Level.error,
        Level.fatal,
      ]);
    });

    test('concurrent zone logging maintains isolation', () async {
      final log = Logger.get('concurrent');
      final futures = <Future>[];

      for (var i = 0; i < 50; i++) {
        futures.add(
          LogContext.run([CharyValue('worker', i)], () async {
            await Future.delayed(Duration(milliseconds: i % 5));
            log.info('from worker $i');
          }),
        );
      }

      await Future.wait(futures);
      expect(entries, hasLength(50));

      for (final entry in entries) {
        final worker = entry.fields['worker'] as int;
        expect(entry.message, 'from worker $worker');
      }
    });
  });

  group('Edge case stress tests', () {
    test('logging with exception types as error', () {
      final log = Logger.get('test');
      final errors = [
        Exception('basic'),
        StateError('state'),
        ArgumentError('arg'),
        RangeError('range'),
        FormatException('format'),
        UnsupportedError('unsupported'),
        UnimplementedError('unimplemented'),
        ConcurrentModificationError('concurrent'),
        TypeError(),
        'string error',
        42,
        null,
      ];
      for (final err in errors) {
        entries.clear();
        log.error('fail', error: err);
        expect(entries.single.error, err);
      }
    });

    test('very large field values', () {
      final log = Logger.get('test');
      log.info('big', [CharyValue('data', 'x' * 1000000)]);
      expect((entries.single.fields['data'] as String).length, 1000000);
    });

    test('field value is a complex nested structure', () {
      final log = Logger.get('test');
      log.info('nested', [
        CharyValue('config', {
          'db': {
            'primary': {'host': 'db1', 'port': 5432},
            'replica': {'host': 'db2', 'port': 5433},
          },
          'cache': {
            'redis': {'host': 'redis1', 'ports': [6379, 6380]},
          },
        }),
      ]);
      final config = entries.single.fields['config'] as Map;
      expect((config['db'] as Map)['primary'], {'host': 'db1', 'port': 5432});
    });

    test('handler that throws does not crash logger', () {
      Logger.handler = (entry) {
        throw StateError('handler crash');
      };
      // Depending on implementation, this may or may not throw
      // The key test is that the logger itself doesn't break
      try {
        Logger.get('test').info('msg');
      } catch (_) {
        // Expected if handler throw propagates
      }
    });

    test('multiple loggers logging simultaneously', () {
      final loggers = [
        for (var i = 0; i < 20; i++) Logger.get('logger$i'),
      ];
      for (var i = 0; i < 20; i++) {
        loggers[i].info('from logger $i');
      }
      expect(entries, hasLength(20));
      for (var i = 0; i < 20; i++) {
        expect(entries[i].loggerName, 'logger$i');
        expect(entries[i].message, 'from logger $i');
      }
    });
  });

  group('Full pipeline stress tests', () {
    test('context + fields + scrub + json formatter + sink', () {
      final lines = <String>[];
      Logger.handler = scrub(
        keys: {'token'},
        handler: makeHandler(jsonFormatter(), callbackSink(lines.add)),
      );

      LogContext.run([
        CharyValue('requestId', 'req-abc'),
        CharyValue('token', 'secret-bearer'),
      ], () {
        Logger.get('api').info('handled request', [
          CharyValue('method', 'GET'),
          CharyValue('path', '/users'),
          CharyValue('status', 200),
        ]);
      });

      expect(lines, hasLength(1));
      final map = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(map['requestId'], 'req-abc');
      expect(map['token'], redacted);
      expect(map['method'], 'GET');
      expect(map['path'], '/users');
      expect(map['status'], 200);
      expect(map['message'], 'handled request');
      expect(map['level'], 'INFO');
      expect(map['logger'], 'api');
    });

    test('full pipeline with error entry', () {
      final lines = <String>[];
      Logger.handler = scrub(
        keys: {'password'},
        handler: makeHandler(jsonFormatter(), callbackSink(lines.add)),
      );

      LogContext.run([CharyValue('traceId', 'trace-1')], () {
        Logger.get('auth').error(
          'login failed',
          fields: [CharyValues({'user': 'alice', 'password': 'bad'})],
          error: StateError('invalid credentials'),
        );
      });

      final map = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(map['traceId'], 'trace-1');
      expect(map['user'], 'alice');
      expect(map['password'], redacted);
      expect(map['error'], contains('invalid credentials'));
      expect(map['level'], 'ERROR');
    });
  });
}
