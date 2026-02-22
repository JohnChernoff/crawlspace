import 'dart:math';
import 'package:crawlspace_engine/object.dart';

import '../foosham/foosham.dart';
import '../foosham/throws.dart';
import '../fugue_engine.dart';
import '../menu.dart';
import '../pilot.dart';
import '../planet.dart';
import '../ship.dart';
import '../shop.dart';
import '../galaxy/system.dart';
import '../systems/ship_system.dart';
import 'fugue_controller.dart';

class MenuController extends FugueController {
  final rootMenu = MenuContext(mode: InputMode.main, builder: () => []);
  late final List<MenuContext> menuStack = [rootMenu];
  MenuContext get currentMenu => menuStack.last;
  InputMode get inputMode => currentMenu.mode;
  String get currentMenuTitle => currentMenu.headerTxt;
  List<MenuEntry> _currentPage = [];
  List<MenuEntry> get selectionList => _currentPage;

  MenuController(super.fm);

  void exitMenu() { //print("Exit Menu called");
    if (menuStack.length > 1) { //print("Exiting...");
      menuStack.removeLast();
      _rebuildMenu();
    }
    fm.update(noWait: true);
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
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.light))
      ActionEntry("s", "(s)cout the system", (m) => fm.planetsideController.scout(), exitAfter: false),
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.medium))
      ActionEntry("h", "(h)ack the network for clues about Star One", (m) => fm.planetsideController.hack(), exitAfter: false),
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.heavy))
      ActionEntry("a", "reveal (a)gent locations", (m) => fm.planetsideController.spy(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.none))
      ActionEntry("v", "(v)isit the tavern", (m) => fm.planetsideController.newFooShamGame(ThrowList.quantum), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.light))
      ActionEntry("t", "(t)rade mission", (m) => fm.planetsideController.getTradeMission(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.medium)) //&& planet.tier(planet.industry).atOrAbove(DistrictLvl.medium))
      ActionEntry("b", "(b)rowse shop", (m) => fm.planetsideController.shop(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.light))
      ActionEntry("r", "(r)epair ship", (m) => fm.planetsideController.enterRepairShop(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.medium))
      ActionEntry("g", "(g)enetic engineering", (m) => fm.planetsideController.bioHack(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.heavy))
      ActionEntry("y", "visit the ship(y)ard", (m) => fm.planetsideController.enterShipyard(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.heavy) && planet.tier(planet.population).atOrAbove(DistrictLvl.heavy))
      ActionEntry("i", "broadcast (i)nformation about Star One", (m) => fm.planetsideController.broadcast(), exitAfter: false),
      ActionEntry("l", "(l)aunch", (m) => fm.planetsideController.launch(), exitAfter: true),
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
                  fm.msgController.addMsg(result.toString()); //TODO: exit on game completion
                  //if (game.winner == null) { showMenu(() => createThrowMenu(pilot, game)); } else { exitMenu(); }
          },exitAfter: game.winner != null)
    ];
  }

  List<MenuEntry> createUninstallMenu(Ship ship) {
    final systems = ship.getAllSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter(i),"${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.msgController.addResultMsg(fm.pilotController.uninstallSystem(system, ship)),exitAfter: true)
    ];
  }

  List<MenuEntry> createInstallMenu(Ship ship) {
    final systems = ship.uninstalledSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter(i),"${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.pilotController.installSystem(ship, system),
            exitAfter: false, disabledReason: () => (ship.availableSlotsbySystem(systems[i]).isEmpty ? "No available slot" : null))
    ];
  }

  List<MenuEntry> createInstallSlotMenu(Ship ship, ShipSystem system) {
    final slots = ship.availableSlotsbySystem(system).map((s) => s.slot).toList();
    return <MenuEntry> [
      for (int i = 0; i < slots.length; i++)
        ValueEntry(letter(i),"${slots[i]}", slots[i],
                (slot) => fm.msgController.addResultMsg(fm.pilotController.installSystem(ship, system, slot: slot)), exitAfter: true)
    ];
  }

  List<MenuEntry> createShopBuyMenu(Shop shop, {Ship? ship}) {
    final entries = <MenuEntry> [
      TextEntry("Credits: ${fm.player.credits}"),
      for (int i = 0; i < shop.itemSlots.length; i++) slotEntry(shop.itemSlots.elementAt(i), letter(i), shop, ship)
    ];
    if (shop.type == ShopType.shipyard) {
      entries.add(ActionEntry("z","enter hangar", (m) => showMenu(() => createHangarMenu(shop.location))));
    } else {
      entries.add(ActionEntry("s","(s)ell", (m) => showMenu(() => createShopSellMenu(shop, ship: ship))));
    }
    return entries;
  }

  List<MenuEntry> createHangarMenu(SpaceEnvironment shop) {
    return <MenuEntry> [
    for (int i = 0; i < shop.hangar.length; i++) ValueEntry(
      letter(i),
      shop.hangar.elementAt(i).shopDesc,
      shop.hangar.elementAt(i),
    (m) => fm.newShip(fm.player, shop.hangar.elementAt(i)),exitAfter: true)
    ];
  }

  //TODO: make player inventory like shops?
  List<MenuEntry> createShopSellMenu(Shop shop, {Ship? ship}) { //TODO: filter by shop type
    final installed = ship?.getAllSystems ?? [];
    final items = [
      ...ship?.inventory.where((i) => !installed.contains(i)) ?? [],
      ...ship?.scrapHeap ?? [],
    ];
    return <MenuEntry> [
      for (int i = 0; i < items.length; i++)
        ValueEntry(letter(i),"${items[i].name} , ${items[i].baseCost}", items[i], //TODO: show cost modifier?
                (item) {
              fm.msgController.addMsg(shop.transactionBuy(item, ship: ship)); //createAndShowShopMenu(shop, ship, true); //refresh shop
            },exitAfter: true)
    ];
  }

  //unused
  /*
  void createAndShowShopMenu(Shop shop, Ship ship, bool refresh) {
    if (refresh) replaceTopMenuFull(() => createShopMenu(shop, ship));  // maxListLength: 12);
    else showMenu(() => createShopMenu(shop, ship));
  } */

  ShopItemEntry slotEntry(ShopSlot itemSlot, String ltr, Shop shop, Ship? ship) {
    final slot = itemSlot;
    if (slot.items.isNotEmpty) {
      final count = slot.items.length > 1 ? ", quantity: ${slot.items.length}" : '';
      final desc =  slot.items.first.shopDesc;
      final credits = "${slot.items.first.baseCost} credits";
      final label = (slot.items.first.shopDesc.endsWith("\n")) ? "$desc$credits$count" : "$desc ($credits$count)";
      return ShopItemEntry(ltr,label, slot, (shopSlot) => confirm("Purchse?", () {
                 fm.msgController.addMsg(shop.transactionSell(shopSlot, ship: ship));
          }), shopper: ship?.pilot ?? fm.player, exitAfter: false);
    }
    return ShopItemEntry(ltr, "empty inventory slot", null, (e) => {}, shopper: ship?.pilot ?? fm.player); //shouldn't occur
  }

  void confirm(String query, VoidCallback action, {VoidCallback? noAction}) {
    showMenu(() => [
      ActionEntry("y", "(y)es", (m) => action(), exitAfter: true),
      ActionEntry("n", "(n)o", (m) { noAction?.call(); }, exitAfter: true),
    ],headerTxt: query, noExit: true);
  }

  void showMenu(MenuBuilder builder, { InputMode? mode, String? headerTxt, String? nothingTxt, int? maxEntries, bool? noExit, int? firstEntry}) {
    menuStack.add(MenuContext.fromBuilder(builder, m: mode, ht: headerTxt, nt: nothingTxt, me: maxEntries, ne: noExit, fe: firstEntry));
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

  void _rebuildMenu({emptyExit = true}) {
    if (menuStack.isEmpty) return;

    final ctx = currentMenu;
    final full = ctx.builder();

    if (full.isEmpty) { //fm.msgController.addMsg(ctx.nothingTxt);
      if (emptyExit || ctx.noExit) {
        exitMenu();
        return;
      }
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
    glog(menuStack.map((m)=>m.headerTxt).join(" > "),level: DebugLevel.Info);
  }

  //void refreshMenu() { if (_lastBuilder != null) replaceTopMenuFull(_lastBuilder!); }

}