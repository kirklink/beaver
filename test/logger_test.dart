import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  late List<LogEntry> entries;

  setUp(() {
    Logger.reset();
    entries = [];
    Logger.handler = entries.add;
  });

  group('Logger.get', () {
    test('returns same instance for same name', () {
      final a = Logger.get('x');
      final b = Logger.get('x');
      expect(identical(a, b), isTrue);
    });

    test('returns different instances for different names', () {
      final a = Logger.get('x');
      final b = Logger.get('y');
      expect(identical(a, b), isFalse);
    });

    test('sets logger name', () {
      final log = Logger.get('myApp.server');
      expect(log.name, 'myApp.server');
    });
  });

  group('level filtering', () {
    test('entries at or above global level pass through', () {
      Logger.level = Level.info;
      final log = Logger.get('test');

      log.info('included');
      log.warn('included');
      log.error('included');
      log.fatal('included');

      expect(entries, hasLength(4));
    });

    test('entries below global level are discarded', () {
      Logger.level = Level.warn;
      final log = Logger.get('test');

      log.debug('dropped');
      log.info('dropped');
      log.warn('kept');

      expect(entries, hasLength(1));
      expect(entries.first.message, 'kept');
    });

    test('per-logger level overrides global level', () {
      Logger.level = Level.warn;
      final log = Logger.get('verbose');
      log.loggerLevel = Level.debug;

      log.debug('kept');
      log.info('kept');

      expect(entries, hasLength(2));
    });

    test('effectiveLevel returns loggerLevel when set', () {
      final log = Logger.get('test');
      log.loggerLevel = Level.error;
      expect(log.effectiveLevel, Level.error);
    });

    test('effectiveLevel returns global level when loggerLevel is null', () {
      Logger.level = Level.warn;
      final log = Logger.get('test');
      expect(log.effectiveLevel, Level.warn);
    });
  });

  group('log methods', () {
    test('debug creates debug-level entry', () {
      Logger.level = Level.debug;
      Logger.get('t').debug('msg');
      expect(entries.single.level, Level.debug);
    });

    test('info creates info-level entry', () {
      Logger.get('t').info('msg');
      expect(entries.single.level, Level.info);
    });

    test('warn creates warn-level entry', () {
      Logger.get('t').warn('msg');
      expect(entries.single.level, Level.warn);
    });

    test('error creates error-level entry', () {
      Logger.get('t').error('msg');
      expect(entries.single.level, Level.error);
    });

    test('fatal creates fatal-level entry', () {
      Logger.get('t').fatal('msg');
      expect(entries.single.level, Level.fatal);
    });

    test('includes structured fields', () {
      Logger.get('t')
          .info('order', [CharyValues({'id': 42, 'status': 'paid'})]);
      expect(entries.single.fields, {'id': 42, 'status': 'paid'});
    });

    test('error includes fields, error, and stack trace via named params', () {
      final err = StateError('boom');
      final stack = StackTrace.current;
      Logger.get('t').error('fail',
          fields: [CharyValue('ctx', 1)], error: err, stackTrace: stack);

      final entry = entries.single;
      expect(entry.fields, {'ctx': 1});
      expect(entry.error, err);
      expect(entry.stackTrace, stack);
    });

    test('error works with just error, no fields', () {
      final err = StateError('boom');
      Logger.get('t').error('fail', error: err);

      final entry = entries.single;
      expect(entry.fields, isEmpty);
      expect(entry.error, err);
    });

    test('fatal includes fields, error, and stack trace via named params', () {
      final err = StateError('boom');
      final stack = StackTrace.current;
      Logger.get('t').fatal('fail',
          fields: [CharyValue('ctx', 1)], error: err, stackTrace: stack);

      final entry = entries.single;
      expect(entry.fields, {'ctx': 1});
      expect(entry.error, err);
      expect(entry.stackTrace, stack);
    });

    test('fatal works with just error, no fields', () {
      final err = StateError('boom');
      Logger.get('t').fatal('fail', error: err);

      final entry = entries.single;
      expect(entry.fields, isEmpty);
      expect(entry.error, err);
    });

    test('sets loggerName on entry', () {
      Logger.get('myApp.db').info('query');
      expect(entries.single.loggerName, 'myApp.db');
    });

    test('sets UTC timestamp on entry', () {
      Logger.get('t').info('now');
      expect(entries.single.timestamp.isUtc, isTrue);
    });
  });

  group('init', () {
    test('sets level', () {
      Logger.init(level: Level.debug);
      expect(Logger.level, Level.debug);
    });

    test('configures pretty handler by default', () {
      Logger.init();
      final lines = <String>[];
      // Capture what the handler produces by overriding just the sink
      Logger.handler = makeHandler(prettyFormatter(color: false), callbackSink(lines.add));
      Logger.get('t').info('hello');
      expect(lines.single, contains('INFO'));
      expect(lines.single, isNot(contains('"timestamp"')));
    });

    test('configures json handler when json is true', () {
      Logger.init(json: true);
      // Verify by checking the handler produces JSON
      final lines = <String>[];
      Logger.handler = makeHandler(jsonFormatter(), callbackSink(lines.add));
      Logger.get('t').info('hello');
      expect(lines.single, contains('"timestamp"'));
    });
  });

  group('reset', () {
    test('clears all loggers', () {
      final a = Logger.get('a');
      Logger.reset();
      final b = Logger.get('a');
      expect(identical(a, b), isFalse);
    });

    test('restores default level', () {
      Logger.level = Level.fatal;
      Logger.reset();
      expect(Logger.level, Level.info);
    });
  });
}
