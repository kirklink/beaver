import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  setUp(() => Logger.reset());

  group('LogContext', () {
    test('current returns empty map outside any zone', () {
      expect(LogContext.current, isEmpty);
    });

    test('run sets fields in zone', () {
      LogContext.run([CharyValue('requestId', 'abc')], () {
        expect(LogContext.current, {'requestId': 'abc'});
      });
    });

    test('current returns empty map outside run callback', () {
      LogContext.run([CharyValue('key', 'value')], () {});
      expect(LogContext.current, isEmpty);
    });

    test('nested run merges parent and child fields', () {
      LogContext.run([CharyValue('service', 'swoop')], () {
        LogContext.run([CharyValue('requestId', 'abc')], () {
          expect(LogContext.current, {
            'service': 'swoop',
            'requestId': 'abc',
          });
        });
      });
    });

    test('child fields override parent on key collision', () {
      LogContext.run([CharyValue('env', 'staging')], () {
        LogContext.run([CharyValue('env', 'test')], () {
          expect(LogContext.current['env'], 'test');
        });
        expect(LogContext.current['env'], 'staging');
      });
    });

    test('fields propagate through await', () async {
      await LogContext.run([CharyValue('traceId', 't1')], () async {
        await Future.delayed(Duration.zero);
        expect(LogContext.current['traceId'], 't1');
      });
    });

    test('fields appear in log entries', () {
      final entries = <LogEntry>[];
      Logger.handler = entries.add;

      LogContext.run([CharyValue('requestId', 'req-1')], () {
        Logger.get('test').info('hello');
      });

      expect(entries.single.fields['requestId'], 'req-1');
    });

    test('explicit log fields override context fields on collision', () {
      final entries = <LogEntry>[];
      Logger.handler = entries.add;

      LogContext.run([CharyValue('source', 'context')], () {
        Logger.get('test')
            .info('hello', [CharyValue('source', 'explicit')]);
      });

      expect(entries.single.fields['source'], 'explicit');
    });

    test('context fields merge with explicit fields', () {
      final entries = <LogEntry>[];
      Logger.handler = entries.add;

      LogContext.run([CharyValue('requestId', 'req-1')], () {
        Logger.get('test').info('order', [CharyValue('orderId', 42)]);
      });

      final fields = entries.single.fields;
      expect(fields['requestId'], 'req-1');
      expect(fields['orderId'], 42);
    });

    test('context fields appear in JSON output', () {
      final lines = <String>[];
      Logger.handler =
          makeHandler(jsonFormatter(), callbackSink(lines.add));

      LogContext.run([CharyValue('requestId', 'req-xyz')], () {
        Logger.get('app').info('handled');
      });

      expect(lines.single, contains('"requestId":"req-xyz"'));
    });
  });
}
