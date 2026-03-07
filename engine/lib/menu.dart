import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/actors/pilot.dart';
import 'controllers/menu_controller.dart';
import 'item.dart';

enum MenuLevel {main,planet,tavern,bar,mainFoosham,fooshamGame,shopMain,misc}

typedef MenuBuilder = List<MenuEntry> Function();
typedef VoidCallback = void Function();
typedef BoolFn = bool Function();
typedef StringFn = String? Function();

class MenuContext {

  MenuBuilder builder;
  final MenuLevel level;
  final String headerTxt;
  final String nothingTxt;
  final int maxEntries;
  final bool noExit;
  int firstEntry;
  static const defMode = InputMode.menu;
  static const defHeadTxt = "Select: ";
  static const defNothingTxt = "Nothing found";
  static const defMaxEntries = 12;
  static const defNoExit = false;
  static const defFirstEntry = 0;
  static const defLevel = MenuLevel.misc;

  MenuContext({
    required this.builder,
    this.headerTxt = defHeadTxt,
    this.nothingTxt = defNothingTxt,
    this.maxEntries = defMaxEntries,
    this.noExit = defNoExit,
    this.firstEntry = defFirstEntry,
    this.level = defLevel
  });

  factory MenuContext.fromBuilder(MenuBuilder b, {InputMode? m, String? ht, String? nt, int? me, bool? ne, int? fe, MenuLevel? lvl}) =>
      MenuContext(builder: b,
          headerTxt: ht ?? defHeadTxt,
          nothingTxt: nt ?? defNothingTxt,
          maxEntries: me ?? defMaxEntries,
          noExit: ne ?? defNoExit,
          firstEntry: fe ?? defFirstEntry,
          level: lvl ?? defLevel
      );
}

abstract class MenuEntry {
  final String? letter;
  final String? label;
  final List<TextBlock> txtBlocks;
  final bool exitBefore,exitAfter;
  final String? Function() disabledReason;
  bool get enabled => disabledReason() == null;

  MenuEntry({this.letter,
        this.label,
        this.txtBlocks = const [],
        this.exitBefore = false,
        this.exitAfter = false,
        StringFn? disabledReason,
      }) : disabledReason = disabledReason ?? (() => null);

  void activate(MenuController mc);
}

class TextEntry extends MenuEntry {
  TextEntry({super.label,super.txtBlocks});
  @override
  void activate(MenuController mc) {}
}

class ActionEntry extends MenuEntry {
  final void Function(MenuController) action;

  ActionEntry(this.action,{super.letter, super.label, super.txtBlocks, super.exitBefore, super.exitAfter, super.disabledReason});

  @override
  void activate(MenuController mc) {
    if (enabled) {
      if (exitBefore) mc.exitMenu();
      action(mc); // run first
      if (!exitBefore) {
        if (exitAfter) mc.exitMenu();
        else mc.rebuild();
      }
    }
  }
}

class ValueEntry<T> extends MenuEntry {
  final T value;
  final void Function(T) onSelect;

  ValueEntry(this.value, this.onSelect, {super.letter, super.label, super.txtBlocks, super.exitBefore, super.exitAfter, super.disabledReason});

  @override
  void activate(MenuController mc) {
    if (enabled) {
      if (exitBefore) mc.exitMenu();
      onSelect(value);
      if (!exitBefore) {
        if (exitAfter) mc.exitMenu();
        else mc.rebuild();
      }
    }
  }
}

class ShopItemEntry<T> extends ValueEntry<T> {
  Pilot shopper;

  @override
  String? Function() get disabledReason => () => !canAfford ? "Can't afford" : null;

  bool get canAfford {   // TODO: use shop to determine actual cost
    final v = value; if (v is ItemSlot) {
      final cost = v.items.firstOrNull?.baseCost ?? 0;
      return shopper.credits >= cost;
    }
    return false;
  }

  ShopItemEntry(super.value, super.onSelect, {super.letter, super.label, super.txtBlocks, required this.shopper, super.exitAfter});

}

class ResultMessage {
  final bool success;
  final String msg;
  const ResultMessage(this.msg, this.success);
}
