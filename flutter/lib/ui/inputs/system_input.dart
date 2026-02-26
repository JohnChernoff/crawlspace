import 'package:flutter/services.dart';
import 'letter_input.dart';

class SystemInput extends LetterInput {

  const SystemInput(super.child, super.fm, {super.key, super.raw});

  @override
  void handleLetter(String letter, {LogicalKeyboardKey? key}) { //print("Letter: ${letter.codeUnits}");
    final spf = fm.menuController.systemSearchPrefix;
    if (letter.length == 1) {
      fm.menuController.systemSearchPrefix = "$spf$letter";
    } else if (key == LogicalKeyboardKey.enter) {
      final system = fm.menuController.selectedSystem;
      if (system != null) fm.menuController.systemCompleter?.complete(system);
    } else if (key == LogicalKeyboardKey.backspace) {
      if (spf.isNotEmpty) fm.menuController.systemSearchPrefix = spf.substring(0,spf.length-1);
    } else if (key == LogicalKeyboardKey.escape) {
      fm.menuController.systemCompleter?.complete(null);
    }
    fm.update();
  }

}