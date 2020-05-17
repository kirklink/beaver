
import 'dart:convert' show LineSplitter;

enum Level {
  off,
  fatal,
  error,
  warn,
  info,
  debug,
  trace,
  all
}

enum Color {

  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  reset

}


class Box {
  static const topLeft = '\u250C';
  static const topRight = '\u2510';
  static const bottomLeft = '\u2514';
  static const bottomRight = '\u2518';
  static const leftJunction = '\u251C';
  static const rightJunction = '\u2524';
  static const line = '\u2500';
  static const side = '\u2502';
  static const leftSide = Box.side + ' ';
  static const rightSide = ' ' + Box.side;

  final int width;
  int _freeSpace;
  String _borderColor;
  String _colorReset;
  final lines = StringBuffer();

  Box(this.width, Color borderColor) {
    _borderColor = _colorCode(borderColor);
    _colorReset = _colorCode(Color.reset);
    _freeSpace = width - 4;
  }

  void borderTop() {
    lines.writeln('$_borderColor${Box.topLeft}${Box.line*(width-2)}${Box.topRight}$_colorReset');
  } 

  void borderRow() {
    lines.writeln('$_borderColor${Box.leftJunction}${Box.line*(width-2)}${Box.rightJunction}$_colorReset');
  }

  void emptyRow() {
    lines.writeln('$_borderColor${Box.leftSide}${' '*(width-4)}${Box.rightSide}$_colorReset');
  }

  void borderBottom() {
    lines.writeln('$_borderColor${Box.bottomLeft}${Box.line*(width-2)}${Box.bottomRight}$_colorReset');
  }

  void textRow(String text, {Color textColor = Color.white}) {
    // Do each line
    final textLines = LineSplitter.split(text);
    for (var line in textLines) {
      // Split up the words in the line
      final parts = line.split(' ');
      var nextLine = <String>[];
      var counter = 0;
      // Iterate through the words
      for (final part in parts) {
        // If the word is really big, break it down into smaller parts
        if (part.length > _freeSpace) {
          final splits = part.length ~/ _freeSpace;
          final lastSplit = part.length % _freeSpace;
          // Handle the full length splits
          for (var i = 0; i < splits; i++) {
            final t = part.substring(i * _freeSpace, (i * _freeSpace + _freeSpace));
            _buildTextLine(textColor, t);
          }
          // Handle the remainder of the split, attach it to the scan of the line
          final lastPart = part.substring(_freeSpace * splits, _freeSpace * splits + lastSplit);
          nextLine = <String>[];
          nextLine.add(lastPart);
          counter = lastPart.length + 1;
        } else {
          counter = counter + part.length;
          // If the word is going to overflow
          if (counter > _freeSpace) {
            // Write the line
            final t = nextLine.join(' ');
            _buildTextLine(textColor, t);
            // Start a new line
            nextLine = <String>[];
            nextLine.add(part);
            counter = part.length + 1;
          } else {
            // Otherwise write the word
            nextLine.add(part);
            counter++;
          }
        }
      }
      // Clean up any partially completed lines
      if (nextLine.isNotEmpty) {
        final t = nextLine.join(' ');
        _buildTextLine(textColor, t);
      }
    }
  }

  void draw() {
    print(lines.toString());
  }

  void _buildTextLine(Color color, String text) {
    final c = _colorCode(color);
    lines.writeln(_borderColor + Box.leftSide + c + text + (' ' * (_freeSpace - text.length)) + _borderColor + Box.rightSide + _colorReset);
  }

  String _colorCode(Color color) {
    switch (color) {
      case Color.black: 
        return '\u001b[30m';
        break;
      case Color.red:
        return '\u001b[31m';
        break;
      case Color.green:
        return '\u001b[32m';
        break;
      case Color.yellow:
        return '\u001b[33m';
        break;
      case Color.blue:
        return '\u001b[34m';
        break;
      case Color.magenta:
        return '\u001b[35m';
        break;
      case Color.cyan:
        return '\u001b[36m';
        break;
      case Color.white:
        return '\u001b[37m';
        break;
      case Color.reset:
        return '\u001b[0m';
        break;
      default:
        return '\u001b[0m';
    }
  }

}

class Beaver {

  final int level;
  int _width;

  factory Beaver(Level level, {int width = 80}) {
    final r = _loggers[level.index];
    r._width = width;
    return r;
  }
  
  Beaver._(this.level);

  void fatal(Object message, {Exception exception, StackTrace stackTrace}) {
    if (_shouldLog(Level.fatal)) {
      _log('- !!! FATAL !!! -', Color.red, Color.red, message, e: exception, s: stackTrace);
    }
  }
  
  void error(Object message, {Exception exception, StackTrace stackTrace}) {
    if (_shouldLog(Level.error)) {
      _log('- !! ERROR !! -', Color.red, Color. yellow, message, e: exception, s: stackTrace);
    }
  }

  void warn(Object message, {Exception exception, StackTrace stackTrace}) {
    if (_shouldLog(Level.warn)) {
      _log('- ! WARN ! -', Color.yellow, Color.yellow, message, e: exception, s: stackTrace);
    }
  }

  void info(Object message, {Exception exception, StackTrace stackTrace}) {
    if (_shouldLog(Level.info)) {
      _log('- INFO -', Color.blue, Color.white, message, e: exception, s: stackTrace);
    }
  }

  void debug(Object message, {Exception exception, StackTrace stackTrace}) {
    if (_shouldLog(Level.debug)) {
      _log('- DEBUG -', Color.green, Color.yellow, message, e: exception, s: stackTrace);
    }
  }

  void trace(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.fatal)) {
      _log('- TRACE -', Color.magenta, Color.white, message, e: exception, s: stacktrace);
    }
  }

  bool _shouldLog(Level l) {
    if (level == Level.off) {
      return false;
    } else if (level == Level.all) {
      return true;
    } else {
      return level >= l.index;
    }
  }


  void _log(String label, Color border, Color text, Object o, {Exception e, StackTrace s}) {
    final box = Box(_width, border);
    box.borderTop();
    box.textRow(label, textColor: text);
    box.borderRow();
    box.textRow(o.toString(), textColor: text);
    if (e != null) {
      box.borderRow();
      box.textRow(e.toString(), textColor: text);
    }
    if (s != null) {
      box.borderRow();
      final split = LineSplitter.split(s.toString());
      for (final sp in split) {
        box.textRow(sp.toString(), textColor: text);
      }
      
      
    }
    box.borderBottom();
    box.draw();
  }

  // static const Exception _emptyException = _EmptyException();
  static List<Beaver> _loggers = List<Beaver>.generate(8, (i) => Beaver._(i));


}