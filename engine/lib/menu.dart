import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/shop.dart';
import 'controllers/menu_controller.dart';

typedef MenuBuilder = List<MenuEntry> Function();
typedef VoidCallback = void Function();
typedef BoolFn = bool Function();
typedef StringFn = String? Function();

class MenuContext {

  MenuBuilder builder;
  final InputMode mode;
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

  MenuContext({
    required this.builder,
    required this.mode,
    this.headerTxt = defHeadTxt,
    this.nothingTxt = defNothingTxt,
    this.maxEntries = defMaxEntries,
    this.noExit = defNoExit,
    this.firstEntry = defFirstEntry,
  });

  factory MenuContext.fromBuilder(MenuBuilder b, {InputMode? m, String? ht, String? nt, int? me, bool? ne, int? fe}) =>
      MenuContext(builder: b,
          mode: m ?? defMode,
          headerTxt: ht ?? defHeadTxt,
          nothingTxt: nt ?? defNothingTxt,
          maxEntries: me ?? defMaxEntries,
          noExit: ne ?? defNoExit,
          firstEntry: fe ?? defFirstEntry
      );
}

enum InputMode {
  main(false),
  menu(true),
  planet(true);
  final bool showMenu;
  const InputMode(this.showMenu);
}

abstract class MenuEntry {
  final String letter;
  final String label;
  final bool exitAfter;
  final String? Function() disabledReason;
  bool get enabled => disabledReason() == null;

  MenuEntry(
      this.letter,
      this.label, {
        this.exitAfter = false,
        StringFn? disabledReason,
      }) : disabledReason = disabledReason ?? (() => null);

  void activate(MenuController mc);
}

class ActionEntry extends MenuEntry {
  final void Function(MenuController) action;

  ActionEntry(super.letter, super.label, this.action, {super.exitAfter,super.disabledReason});

  @override
  void activate(MenuController mc) {
    if (enabled) {
      action(mc); // run first
      if (exitAfter) mc.exitMenu();
      else mc.fm.update();
    }
  }
}

class ValueEntry<T> extends MenuEntry {
  final T value;
  final void Function(T) onSelect;

  ValueEntry(super.letter, super.label, this.value, this.onSelect, {super.exitAfter,super.disabledReason});

  @override
  void activate(MenuController mc) {
    if (enabled) {
      onSelect(value);
      if (exitAfter) mc.exitMenu();
      else mc.fm.update();
    }
  }
}

class ShopItemEntry<T> extends ValueEntry<T> {
  Pilot shopper;

  @override
  String? Function() get disabledReason => () => !canAfford ? "Can't afford" : null;

  bool get canAfford {   // TODO: use shop to determine actual cost
    final v = value; if (v is ShopSlot) {
      final cost = v.items.firstOrNull?.baseCost ?? 0;
      return shopper.credits >= cost;
    }
    return false;
  }

  ShopItemEntry(super.letter, super.label, super.value, super.onSelect, {required this.shopper, super.exitAfter});

}

class ResultMessage {
  final bool success;
  final String msg;
  const ResultMessage(this.msg, this.success);
}
