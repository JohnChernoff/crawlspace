import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class LetterInput extends StatelessWidget {
  final Widget child;
  final FugueEngine fm;
  final bool raw;

  const LetterInput(this.child, this.fm, {this.raw = false, super.key});

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final char = event.character;
    if (raw) {
      handleLetter(char ?? "", key: event.logicalKey);
      return KeyEventResult.handled;
    }
    if (char != null && char.length == 1) {
      handleLetter(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void handleLetter(String letter, {LogicalKeyboardKey? key});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent:  _handleKey,
      child: child,
    );
  }
}