
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

  String fatal(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.fatal)) {
      final border = noColor ? Color.none : Color.red;
      final text = noColor ? Color.none : Color.red;
      final box = _log('- !!! FATAL !!! -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
    }
  }
  
  String error(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.error)) {
      final border = noColor ? Color.none : Color.red;
      final text = noColor ? Color.none : Color.yellow;
      final box = _log('- !! ERROR !! -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
    }
  }

  String warn(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.warn)) {
      final border = noColor ? Color.none : Color.yellow;
      final text = noColor ? Color.none : Color.yellow;
      final box = _log('- ! WARN ! -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
    }
  }

  String info(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.info)) {
      final border = noColor ? Color.none : Color.blue;
      final text = noColor ? Color.none : Color.white;
      final box = _log('- INFO -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
    }
  }

  String debug(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.debug)) {
      final border = noColor ? Color.none : Color.green;
      final text = noColor ? Color.none : Color.yellow;
      final box = _log('- DEBUG -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
    }
  }

  String trace(Object message, {Exception exception, StackTrace stacktrace, bool noColor = false}) {
    if (_shouldLog(Level.fatal)) {
      final border = noColor ? Color.none : Color.magenta;
      final text = noColor ? Color.none : Color.white;
      final box = _log('- TRACE -', border, text, message, e: exception, s: stacktrace);
      print(box);
      return box;
    } else {
      return '';
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


  String _log(String label, Color border, Color text, Object o, {Exception e, StackTrace s}) {
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
    return box.create();
  }

  // static const Exception _emptyException = _EmptyException();
  static final List<Beaver> _loggers = List<Beaver>.generate(8, (i) => Beaver._(i));


}