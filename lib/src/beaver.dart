
import 'dart:convert' show LineSplitter;

import 'package:beaver/src/enums.dart';
import 'package:beaver/src/box.dart';

class Beaver {

  final int level;
  int _width;

  factory Beaver(Level level, {int width = 80}) {
    final r = _loggers[level.index];
    r._width = width;
    return r;
  }
  
  Beaver._(this.level);

  void fatal(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.fatal)) {
      _log('- !!! FATAL !!! -', Color.red, Color.red, message, e: exception, s: stacktrace);
    }
  }
  
  void error(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.error)) {
      _log('- !! ERROR !! -', Color.red, Color. yellow, message, e: exception, s: stacktrace);
    }
  }

  void warn(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.warn)) {
      _log('- ! WARN ! -', Color.yellow, Color.yellow, message, e: exception, s: stacktrace);
    }
  }

  void info(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.info)) {
      _log('- INFO -', Color.blue, Color.white, message, e: exception, s: stacktrace);
    }
  }

  void debug(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.debug)) {
      _log('- DEBUG -', Color.green, Color.yellow, message, e: exception, s: stacktrace);
    }
  }

  void trace(Object message, {Exception exception, StackTrace stacktrace}) {
    if (_shouldLog(Level.fatal)) {
      _log('- TRACE -', Color.magenta, Color.white, message, e: exception, s: stacktrace);
    }
  }

  bool _shouldLog(Level l) {
    if (level == Level.off.index) {
      return false;
    } else if (level == Level.all.index) {
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
  static final List<Beaver> _loggers = List<Beaver>.generate(8, (i) => Beaver._(i));


}