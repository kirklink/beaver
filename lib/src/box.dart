import 'dart:convert' show LineSplitter;

import 'package:beaver/src/enums.dart';

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
    _borderColor = Box.colorCode(borderColor);
    _colorReset = borderColor == Color.none ? '' : Box.colorCode(Color.reset);
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

  String create() {
    return lines.toString();
  }

  void _buildTextLine(Color color, String text) {
    final c = Box.colorCode(color);
    lines.writeln(_borderColor + Box.leftSide + c + text + (' ' * (_freeSpace - text.length)) + _borderColor + Box.rightSide + _colorReset);
  }

  static String colorCode(Color color) {
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
      case Color.none:
        return '';
        break;
      default:
        return '\u001b[0m';
    }
  }

}