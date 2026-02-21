import 'package:beaver/beaver.dart';
import 'package:test/test.dart';

void main() {
  group('Level', () {
    test('has 5 values in order', () {
      expect(Level.values, [
        Level.debug,
        Level.info,
        Level.warn,
        Level.error,
        Level.fatal,
      ]);
    });

    test('indices are ascending', () {
      for (var i = 1; i < Level.values.length; i++) {
        expect(Level.values[i].index, greaterThan(Level.values[i - 1].index));
      }
    });

    test('every level passes itself', () {
      for (final level in Level.values) {
        expect(level.passes(level), isTrue);
      }
    });

    test('higher levels pass lower thresholds', () {
      expect(Level.fatal.passes(Level.debug), isTrue);
      expect(Level.error.passes(Level.info), isTrue);
      expect(Level.warn.passes(Level.debug), isTrue);
    });

    test('lower levels do not pass higher thresholds', () {
      expect(Level.debug.passes(Level.info), isFalse);
      expect(Level.debug.passes(Level.fatal), isFalse);
      expect(Level.info.passes(Level.warn), isFalse);
    });

    test('compareTo matches index ordering', () {
      expect(Level.debug.compareTo(Level.fatal), isNegative);
      expect(Level.fatal.compareTo(Level.debug), isPositive);
      expect(Level.info.compareTo(Level.info), isZero);
    });
  });
}
