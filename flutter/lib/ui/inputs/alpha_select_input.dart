import 'package:flutter/services.dart';
import 'letter_input.dart';

class SystemInput extends LetterInput {

  const SystemInput(super.child, super.fm, {super.key, super.raw});

  @override
  void handleLetter(String letter, {LogicalKeyboardKey? key}) { //print("Letter: ${letter.codeUnits}");
    final alphaComp = fm.menuController.currAlphaComp;
    if (alphaComp == null) return;
    final spf = alphaComp.searchPrefix;
    if (letter.length == 1) {
      alphaComp.searchPrefix = "$spf$letter";
    } else if (key == LogicalKeyboardKey.enter) {
      alphaComp.complete();
    } else if (key == LogicalKeyboardKey.backspace) {
      if (spf.isNotEmpty) alphaComp.searchPrefix = spf.substring(0,spf.length-1);
    } else if (key == LogicalKeyboardKey.escape) {
      alphaComp.abort();
    } else if (key == LogicalKeyboardKey.arrowDown && alphaComp.selectedIndex < (alphaComp.list.length - 1)) {
      alphaComp.selectedIndex++;
    } else if (key == LogicalKeyboardKey.arrowUp && alphaComp.selectedIndex > 0) {
      alphaComp.selectedIndex--;
    }
    fm.update();
  }

}