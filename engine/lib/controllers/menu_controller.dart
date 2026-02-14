import 'dart:async';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import '../foosham/foosham.dart';
import '../foosham/throws.dart';
import '../pilot.dart';
import '../planet.dart';
import '../ship.dart';
import '../shop.dart';
import '../system.dart';
import '../systems/ship_system.dart';
import 'fugue_controller.dart';

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
  final bool exitMenu;
  bool get enabled => true;

  MenuEntry(this.letter,this.label,{this.exitMenu = false});

  void activate(MenuController menu);
}

class ActionEntry extends MenuEntry {
  final void Function(MenuController) action;

  ActionEntry(super.letter, super.label, this.action, {super.exitMenu});

  @override
  void activate(MenuController menu) {
    if (exitMenu) {
      menu.exitInputMode();
    } else {
      menu.fm.update();
    }
    action(menu);
  }
}

class ValueEntry<T> extends MenuEntry {
  final T value;
  final void Function(T) onSelect;

  ValueEntry(super.letter, super.label, this.value, this.onSelect, {super.exitMenu});

  @override
  void activate(MenuController menu) {
    if (exitMenu) {
      menu.exitInputMode();
    } else {
      menu.fm.update();
    }
    onSelect(value);
  }
}

class ShopItemEntry<T> extends ValueEntry {
  Pilot shopper;

  @override
  // TODO: use shop to determine actual cost
  bool get enabled => shopper.credits > ((value as ShopSlot).items.firstOrNull?.baseCost ?? 0);

  ShopItemEntry(super.letter, super.label, super.value, super.onSelect, {
    required this.shopper, super.exitMenu});

}

class ResultMessage {
  final bool success;
  final String msg;
  const ResultMessage(this.msg, this.success);
}

class ActionCompleter<T> {
  final Completer<T> _completer = Completer<T>();
  final Function() _onComplete;

  ActionCompleter(this._onComplete);

  Future<T> get future => _completer.future;

  void trigger() {
    _onComplete();
  }

  void complete([T? value]) {
    _onComplete();
    _completer.complete(value);
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    _onComplete();
    _completer.completeError(error, stackTrace);
  }
}

class MenuController extends FugueController {
  List<MenuEntry> selectionList = [];
  List<InputMode> inputStack = [InputMode.main];
  InputMode get inputMode => inputStack.last;
  String currentMenuTitle = "";
  MenuController(super.fm);

  void newInputMode(InputMode mode) { //print("Mode: ${inputMode.name} -> ${mode.name}");
    if (inputMode != mode) {
      inputStack.add(mode);
    }
    fm.update();
  }

  InputMode? exitInputMode() {
    final previousMode = (inputStack.length > 1) ? inputStack.removeLast() : null;
    fm.glog("Exited from  ${previousMode?.name} ->  ${inputMode.name}");
    if (previousMode != inputMode) {
      if (inputMode == InputMode.planet && fm.player.planet != null) showPlanetMenu(fm.player.planet!);
    }
    fm.update();
    return previousMode;
  }

  void showHyperSpaceMenu(Map<String,System> currentLinkMap) {
    StringBuffer sb = StringBuffer();
    sb.writeln("Hyperspace Menu");
    for (final letter in currentLinkMap.keys) {
      sb.write("$letter: ${currentLinkMap[letter]}");
    }
    sb.writeln("x: cancel");
    fm.msgController.addMsg(sb.toString());
    //newInputMode(InputMode.hyperspace);
  }

  void showPlanetMenu(Planet planet) {
    List<MenuEntry> activities = [
      ActionEntry("s", "(s)cout the system", (m) => fm.planetsideController.scout(), exitMenu: false),
      ActionEntry("h", "(h)ack the network for clues about Star One", (m) => fm.planetsideController.hack(), exitMenu: false),
      ActionEntry("a", "reveal (a)gent locations", (m) => fm.planetsideController.spy(), exitMenu: false),
      ActionEntry("v", "(v)isit the tavern", (m) => fm.planetsideController.newFooShamGame(ThrowList.quantum), exitMenu: false),
      ActionEntry("t", "(t)rade mission", (m) => fm.planetsideController.getTradeMission(), exitMenu: false),
      ActionEntry("i", "broadcast (i)nformation about Star One", (m) => fm.planetsideController.broadcast(), exitMenu: false),
      ActionEntry("r", "(r)epair ship", (m) => fm.planetsideController.spy(), exitMenu: false),
      ActionEntry("u", "(u)pgrade ship", (m) => fm.planetsideController.spy(), exitMenu: false),
      ActionEntry("g", "(g)enetic engineering", (m) => fm.planetsideController.bioHack(), exitMenu: false),
      ActionEntry("b", "(b)rowse shop", (m) => fm.planetsideController.shop(), exitMenu: false),
      ActionEntry("l", "(l)aunch", (m) => fm.msgController.addMsg("Launching..."), exitMenu: true),
    ];
    showMenu(activities,headerTxt: planet.name, noExit: true, mode: InputMode.planet);
  }

  String letter(int n) => String.fromCharCode(n + 97);

  List<ValueEntry> createThrowMenu(Pilot pilot, FooShamGame game) {
    return <ValueEntry> [
      for (int i = 0; i < game.throwList.list.length; i++)
          ValueEntry(letter(i),game.throwList.list[i],game.throwList.list[i],
                (t) {
                  final result = game.playThrow(t);
                  fm.msgController.addMsg(result.toString());
                  if (game.winner == null) {
                    showMenu(createThrowMenu(pilot, game));
                  } else {
                    exitInputMode();
                  }
          })
    ];
  }

  List<MenuEntry> createUninstallMenu(Ship ship) {
    final systems = ship.getAllSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter(i),"${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.msgController.addResultMsg(fm.pilotController.uninstallSystem(system, ship)),exitMenu: true)
    ];
  }

  List<MenuEntry> createInstallMenu(Ship ship) {
    final systems = ship.uninstalledSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter(i),"${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.pilotController.installSystem(ship, system),exitMenu: true)
    ];
  }

  List<MenuEntry> createInstallSlotMenu(Ship ship, ShipSystem system) {
    final slots = ship.availableSlotsbySystem(system).map((s) => s.slot).toList();
    return <MenuEntry> [
      for (int i = 0; i < slots.length; i++)
        ValueEntry(letter(i),"${slots[i]}", slots[i],
                (slot) => fm.msgController.addResultMsg(fm.pilotController.installSystem(ship, system, slot: slot)),exitMenu: true)
    ];
  }

  List<MenuEntry> createShopMenu(Shop shop, Ship ship) {
    final entries = <MenuEntry> [
      for (int i = 0; i < shop.itemSlots.length; i++) slotEntry(shop.itemSlots.elementAt(i), letter(i), shop, ship)
    ];
    entries.add(ActionEntry("s","(s)ell", (m) => showMenu(createShopSellMenu(ship, shop))));
    return entries;
  }

  ShopItemEntry slotEntry(ShopSlot slot, String ltr, Shop shop, Ship ship) {
    if (slot.items.isNotEmpty) {
      return ShopItemEntry(ltr,"${slot.items.first.name} , ${slot.items.first.baseCost}, ${slot.items.length}", slot,
              (shopSlot) {
            fm.msgController.addMsg(shop.transactionSell(slot, ship));
            showMenu(createShopMenu(shop, ship),headerTxt: shop.name); //refresh shop
          }, shopper: ship.pilot);
    }
    return ShopItemEntry(ltr, "empty inventory slot", null, (e) => {}, shopper: ship.pilot);
  }

  //TODO: make player inventory like shops?
  List<MenuEntry> createShopSellMenu(Ship ship, Shop shop) { //TODO: filter by shop type
    final installed = ship.getAllSystems;
    final items = ship.inventory.toList().where((i) => !installed.contains(i)).asList();
    return <MenuEntry> [
      for (int i = 0; i < items.length; i++)
        ValueEntry(letter(i),"${items[i].name} , ${items[i].baseCost}", items[i], //TODO: show cost modifier?
                (item) {
                  fm.msgController.addMsg(shop.transactionBuy(item, ship));
                  showMenu(createShopMenu(shop, ship),headerTxt: shop.name); //refresh shop
      },exitMenu: false)
    ];
  }

  void showMenu(final List<MenuEntry> menuMap, { //Function? exitAction,
    InputMode mode = InputMode.menu,
    bool noExit = false,
    String headerTxt = "Please select:",
    String nothingTxt = "Nothing found"}) {
    if (menuMap.isEmpty) {
      fm.msgController.addMsg(nothingTxt); return;
    } else {
      final entries = List<MenuEntry>.from(menuMap);
      if (!noExit) entries.add(ActionEntry("x", "e(x)it", (m) => {}, exitMenu: true));
      selectionList = entries;
      currentMenuTitle = headerTxt;
    }
    newInputMode(mode);
  }


}