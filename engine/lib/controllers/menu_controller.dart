import 'dart:math';
import '../foosham/foosham.dart';
import '../foosham/throws.dart';
import '../fugue_engine.dart';
import '../pilot.dart';
import '../planet.dart';
import '../ship.dart';
import '../shop.dart';
import '../system.dart';
import '../systems/ship_system.dart';
import 'fugue_controller.dart';

typedef VoidCallback = void Function();
typedef MenuBuilder = List<MenuEntry> Function();

class MenuContext {
  MenuBuilder builder;
  final InputMode mode;
  final String headerTxt;
  final String nothingTxt;
  final int maxEntries;
  final bool noExit;
  int firstEntry;

  MenuContext({
    required this.builder,
    required this.mode,
    required this.headerTxt,
    required this.nothingTxt,
    required this.maxEntries,
    required this.noExit,
    this.firstEntry = 0,
  });
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
  final bool exitMenu;
  bool get enabled => true;

  MenuEntry(this.letter,this.label,{this.exitMenu = false});

  void activate(MenuController mc);
}

class ActionEntry extends MenuEntry {
  final void Function(MenuController) action;

  ActionEntry(super.letter, super.label, this.action, {super.exitMenu});

  @override
  void activate(MenuController mc) {
    action(mc); // run first
    if (exitMenu) mc.exitMenu();
    else mc.fm.update();
  }
}

class ValueEntry<T> extends MenuEntry {
  final T value;
  final void Function(T) onSelect;

  ValueEntry(super.letter, super.label, this.value, this.onSelect, {super.exitMenu});

  @override
  void activate(MenuController mc) {
    onSelect(value);
    if (exitMenu) mc.exitMenu();
    else mc.fm.update();
  }
}

class ShopItemEntry<T> extends ValueEntry<T> {
  Pilot shopper;

  @override
  bool get enabled {   // TODO: use shop to determine actual cost
    final v = value; if (v is ShopSlot) {
      final cost = v.items.firstOrNull?.baseCost ?? 0;
      return shopper.credits >= cost;
    }
    return false;
   }

  ShopItemEntry(super.letter, super.label, super.value, super.onSelect, {
    required this.shopper, super.exitMenu});

}

class ResultMessage {
  final bool success;
  final String msg;
  const ResultMessage(this.msg, this.success);
}

class MenuController extends FugueController {
  final rootMenu = MenuContext(mode: InputMode.main, builder: () => [], headerTxt: "Main", noExit: true, nothingTxt: "", maxEntries: 0, firstEntry: 0);
  late final List<MenuContext> menuStack = [rootMenu];
  MenuContext get currentMenu => menuStack.last;
  InputMode get inputMode => currentMenu.mode;
  String get currentMenuTitle => currentMenu.headerTxt;
  List<MenuEntry> _currentPage = [];
  List<MenuEntry> get selectionList => _currentPage;

  MenuController(super.fm);

  void exitMenu() {
    print("Exit Menu called");
    if (menuStack.length > 1) {
      print("Exiting...");
      menuStack.removeLast();
      _rebuildMenu();
    } else {
      fm.update();
    }
  }

  //TODO: fix
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
    showMenu(() => activities,headerTxt: planet.name, noExit: true, mode: InputMode.planet);
  }

  String letter(int n) => String.fromCharCode(n + 97);

  List<MenuEntry> createThrowMenu(Pilot pilot, FooShamGame game) {
    return <MenuEntry> [
      for (int i = 0; i < game.throwList.list.length; i++)
          ValueEntry(letter(i),game.throwList.list[i],game.throwList.list[i],
                (t) {
                  final result = game.playThrow(t);
                  fm.msgController.addMsg(result.toString());
                  if (game.winner == null) {
                    showMenu(() => createThrowMenu(pilot, game));
                  } else {
                    exitMenu();
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
    entries.add(ActionEntry("s","(s)ell", (m) => showMenu(() => createShopSellMenu(ship, shop))));
    return entries;
  }

  void createAndShowShopMenu(Shop shop, Ship ship, bool refresh) {
    if (refresh) replaceTopMenuFull(() => createShopMenu(shop, ship));  // maxListLength: 12);
    else showMenu(() => createShopMenu(shop, ship));
  }

  ShopItemEntry slotEntry(ShopSlot itemSlot, String ltr, Shop shop, Ship ship) {
    final slot = itemSlot;
    if (slot.items.isNotEmpty) {
      return ShopItemEntry(ltr,"${slot.items.first.name} , ${slot.items.first.baseCost}, ${slot.items.length}", slot,
              (shopSlot) => confirm("Purchse?", () {
                 fm.msgController.addMsg(shop.transactionSell(shopSlot, ship)); //fm.msgController.addMsg(shop.transactionSell(slot, ship));
          }), shopper: ship.pilot, exitMenu: false);
    }
    return ShopItemEntry(ltr, "empty inventory slot", null, (e) => {}, shopper: ship.pilot);
  }

  void confirm(String query, VoidCallback action, {VoidCallback? noAction}) {
    showMenu(() => [
      ActionEntry("y", "(y)es", (m) => action(), exitMenu: true),
      ActionEntry("n", "(n)o", (m) { noAction?.call(); }, exitMenu: true),
    ],headerTxt: query, noExit: true);
  }

  //TODO: make player inventory like shops?
  List<MenuEntry> createShopSellMenu(Ship ship, Shop shop) { //TODO: filter by shop type
    final installed = ship.getAllSystems;
    final items = [
      ...ship.inventory.where((i) => !installed.contains(i)),
      ...ship.scrapHeap,
    ];
    return <MenuEntry> [
      for (int i = 0; i < items.length; i++)
        ValueEntry(letter(i),"${items[i].name} , ${items[i].baseCost}", items[i], //TODO: show cost modifier?
                (item) {
                   fm.msgController.addMsg(shop.transactionBuy(item, ship)); //createAndShowShopMenu(shop, ship, true); //refresh shop
      },exitMenu: true)
    ];
  }

  void showMenu(
      MenuBuilder builder, {
        InputMode mode = InputMode.menu,
        String headerTxt = "Select:",
        String nothingTxt = "Nothing found",
        int maxEntries = 26,
        bool noExit = false,
        int firstEntry = 0,
      }) {
    menuStack.add(MenuContext(
      builder: builder,
      mode: mode,
      headerTxt: headerTxt,
      nothingTxt: nothingTxt,
      maxEntries: maxEntries,
      noExit: noExit,
      firstEntry: firstEntry,
    ));

    _rebuildMenu();
  }

  void replaceTopMenu({MenuBuilder? builder, int? firstEntry}) {
    final m = currentMenu;
    if (builder != null) m.builder = builder;
    if (firstEntry != null) m.firstEntry = firstEntry;
    _rebuildMenu();
  }

  void replaceTopMenuFull(MenuBuilder builder) {
    final m = currentMenu;
    m.builder = builder;
    m.firstEntry = 0;
    _rebuildMenu();
  }

  void _rebuildMenu() {
    if (menuStack.isEmpty) return;

    final ctx = currentMenu;
    final full = ctx.builder();

    if (full.isEmpty) {
      fm.msgController.addMsg(ctx.nothingTxt);
      exitMenu();
      return;
    }

    final start = ctx.firstEntry;
    final end = min(start + ctx.maxEntries, full.length);
    final page = full.sublist(start, end);

    final hasPrev = start > 0;
    final hasNext = end < full.length;

    if (hasPrev) {
      page.insert(0, ActionEntry("<", "Prev", (_) =>
          replaceTopMenu(firstEntry: max(start - ctx.maxEntries, 0))
      ));
    }

    if (hasNext) {
      page.add(ActionEntry(">", "Next", (_) =>
          replaceTopMenu(firstEntry: start + ctx.maxEntries)
      ));
    }

    if (!ctx.noExit) {
      page.add(ActionEntry("x", "Exit", (_) => exitMenu()));
    }

    _currentPage = page; //assert(page.every((e) => e is MenuEntry));

    fm.update();
    FugueEngine.glog(menuStack.map((m)=>m.headerTxt).join(" > "));
  }

  //void refreshMenu() { if (_lastBuilder != null) replaceTopMenuFull(_lastBuilder!); }

}