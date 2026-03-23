import 'package:crawlspace_engine/fugue_engine.dart';

class Utils {
  static String wrap(String text, {int width = 60}) {
    final words = text.split(' ');
    final buffer = StringBuffer();
    int lineLen = 0;
    for (final word in words) {
      if (lineLen + word.length + 1 > width && lineLen > 0) {
        buffer.write('\n');
        lineLen = 0;
      } else if (lineLen > 0) {
        buffer.write(' ');
        lineLen++;
      }
      buffer.write(word);
      lineLen += word.length;
    }
    return buffer.toString();
  }

  static List<TextBlock> wrapBlock(TextBlock b, {int maxChar = 60}) {
    if (b.txt.length <= maxChar) return [b];
    final words = b.txt.split(' ');
    final lines = <String>[];
    final current = StringBuffer();
    for (final word in words) {
      if (current.length + word.length + (current.isEmpty ? 0 : 1) > maxChar) {
        if (current.isNotEmpty) { lines.add(current.toString()); current.clear(); }
      }
      if (current.isNotEmpty) current.write(' ');
      current.write(word);
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines.map((l) => TextBlock(l, b.color, true)).toList();
  }

  static double lerp(double a, double b, double t) => a + (b - a) * t;

}

