import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  group('makeHandler', () {
    test('calls formatter then sink', () {
      final entry = LogEntry(
        level: Level.info,
        message: 'hello',
        loggerName: 'test',
        timestamp: DateTime.now(),
      );

      String? formatted;
      String? sunk;

      String formatter(LogEntry e) {
        formatted = 'formatted:${e.message}';
        return formatted!;
      }
      void sink(String line) {
        sunk = line;
      }

      final handler = makeHandler(formatter, sink);
      handler(entry);

      expect(formatted, 'formatted:hello');
      expect(sunk, 'formatted:hello');
    });
  });

  group('callbackSink', () {
    test('captures output', () {
      final lines = <String>[];
      final sink = callbackSink(lines.add);
      sink('line one');
      sink('line two');
      expect(lines, ['line one', 'line two']);
    });
  });

  group('integration', () {
    test('logger -> formatter -> sink pipeline', () {
      Logger.reset();
      final lines = <String>[];
      Logger.handler =
          makeHandler(prettyFormatter(color: false), callbackSink(lines.add));

      Logger.get('app').info('started', [CharyValue('port', 8080)]);

      expect(lines, hasLength(1));
      expect(lines.first, contains('INFO'));
      expect(lines.first, contains('app'));
      expect(lines.first, contains('started'));
      expect(lines.first, contains('port=8080'));
    });
  });
}
