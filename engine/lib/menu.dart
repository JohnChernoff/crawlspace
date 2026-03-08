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
  final bool describable;
  int firstEntry;
  static const defMode = InputMode.menu;
  static const defHeadTxt = "Select: ";
  static const defNothingTxt = "Nothing found";
  static const defMaxEntries = 12;
  static const defNoExit = false;
  static const defDescribable = false;
  static const defFirstEntry = 0;
  static const defLevel = MenuLevel.misc;

  MenuContext({
    required this.builder,
    this.headerTxt = defHeadTxt,
    this.nothingTxt = defNothingTxt,
    this.maxEntries = defMaxEntries,
    this.noExit = defNoExit,
    this.describable = defDescribable,
    this.firstEntry = defFirstEntry,
    this.level = defLevel
  });

  factory MenuContext.fromBuilder(MenuBuilder b,
      {InputMode? m, String? ht, String? nt, int? me, bool? ne, bool? desc, int? fe, MenuLevel? lvl}) =>
      MenuContext(builder: b,
          headerTxt: ht ?? defHeadTxt,
          nothingTxt: nt ?? defNothingTxt,
          maxEntries: me ?? defMaxEntries,
          noExit: ne ?? defNoExit,
          describable: desc ?? defDescribable,
          firstEntry: fe ?? defFirstEntry,
          level: lvl ?? defLevel
      );
}

abstract class MenuEntry {
  final String? letter;
  final String? label;
  final List<TextBlock> txtBlocks;
  final bool exitBefore,exitAfter;
  final String? Function()? _disabledReason;
  String? get disabledReason => (_disabledReason ??  (() => null))();
  bool get enabled => disabledReason == null;
  const MenuEntry({this.letter,
        this.label,
        this.txtBlocks = const [],
        this.exitBefore = false,
        this.exitAfter = false,
        String? Function()? disabledReason,
      }) : _disabledReason = disabledReason;

  void activate(MenuController mc);
}

class TextEntry extends MenuEntry {
  TextEntry({super.label,super.txtBlocks});
  @override
  void activate(MenuController mc) => {};
}

class ActionEntry extends MenuEntry {
  final void Function(MenuController) action;

  const ActionEntry(this.action,{super.letter, super.label, super.txtBlocks, super.exitBefore, super.exitAfter, super.disabledReason});

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
  final bool describe;
  final T value;
  final void Function(T) onSelect;

  const ValueEntry(this.value, this.onSelect,
      {super.letter, super.label, super.txtBlocks, super.exitBefore, super.exitAfter, super.disabledReason, this.describe = false});

  factory ValueEntry.stub(T val, {String? lab, List<TextBlock>? blocks }) => ValueEntry(val, (m) => {}, label: lab, txtBlocks: blocks ?? []);

  ValueEntry<T> copyWith({T? value,  void Function(T)? onSelect,
    String? letter, String? label, List<TextBlock>? txtBlocks,
    bool? exitBefore, bool? exitAfter, bool? describe, String? Function()? disabledReason})
  => ValueEntry<T>(value ?? this.value, onSelect ?? this.onSelect,
    letter: letter ?? this.letter,
    label: label ?? this.label,
    txtBlocks: txtBlocks ?? this.txtBlocks,
    exitBefore: exitBefore ?? this.exitBefore,
    exitAfter: exitAfter ?? this.exitAfter,
    describe: describe ?? this.describe,
    disabledReason: disabledReason ?? _disabledReason
  );

  @override
  void activate(MenuController mc) {
    final v = value;
    if (describe && v is Descriable) {
      mc.showMenu(() => [TextEntry(label: v.description)],headerTxt: v.selectionName);
    }
    else {
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
}

class ShopItemEntry<T> extends ValueEntry<T> {
  Pilot shopper;

  @override
  String? get disabledReason => !canAfford ? "Can't afford" : null;

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
