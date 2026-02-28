import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/controllers/menu_controller.dart';
import 'package:crawlspace_engine/rng/drinks.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/planet.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/systems/ship_system.dart';
import 'foosham/foosham.dart';
import 'galaxy/system.dart';
import 'menu.dart';
import 'object.dart';

typedef Menu = List<MenuEntry>;

class MenuFactory {
  final FugueEngine fm;
  MenuController get mc => fm.menuController;
  String letter(int i) => mc.letter(i);
  const MenuFactory(this.fm);

  ShopItemEntry slotEntry(ShopSlot itemSlot, String ltr, Shop shop, Ship? ship) {
    final slot = itemSlot;
    if (slot.items.isNotEmpty) {
      final count = slot.items.length > 1 ? ", quantity: ${slot.items.length}" : '';
      final desc =  slot.items.first.shopDesc;
      final credits = "${slot.items.first.baseCost} credits";
      final label = (slot.items.first.shopDesc.endsWith("\n")) ? "$desc$credits$count" : "$desc ($credits$count)";
      return ShopItemEntry(letter: ltr, label: label, slot, (shopSlot) => mc.confirm("Purchse?", () {
        fm.msgController.addMsg(shop.transactionSell(shopSlot, ship: ship));
      }), shopper: ship?.pilot ?? fm.player, exitAfter: false);
    }
    return ShopItemEntry(letter: ltr, label: "empty inventory slot", null, (e) => {}, shopper: ship?.pilot ?? fm.player); //shouldn't occur
  }

  Menu buildInventoryMenu(Ship ship, {VoidCallback? action}) {
    print("Inventory: ${ship.allInventory}");
    return List.generate(ship.allInventory.length,(i) {
      final shipItem = ship.allInventory.elementAt(i);
      String itemStr = (shipItem is ShipSystem && ship.systemControl.isInstalled(shipItem))
      ? "${shipItem.name} (installed)"
      : shipItem.name;
      if (action != null) return ValueEntry(letter: mc.letter(i), label: itemStr, shipItem, (m) => action);
      else return TextEntry(label: itemStr);
    });
  }

  Menu buildPlanetMenu(Planet planet) {
    return [
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.light))
        ActionEntry(letter:  "s",  label: "(s)cout the system", (m) => fm.planetsideController.scout(), exitAfter: false),
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.medium))
        ActionEntry(letter:  "h", label: "(h)ack the network for clues about Star One", (m) => fm.planetsideController.hack(), exitAfter: false),
      if (planet.tier(planet.population).atOrAbove(DistrictLvl.heavy))
        ActionEntry(letter:  "a", label: "reveal (a)gent locations", (m) => fm.planetsideController.spy(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.none))
        ActionEntry(letter:  "v", label:  "(v)isit the tavern", (m) => mc.showMenu(() => buildTavernMenu(planet)), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.light))
        ActionEntry(letter:  "t", label:  "(t)rade mission", (m) => fm.planetsideController.getTradeMission(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.medium)) //&& planet.tier(planet.industry).atOrAbove(DistrictLvl.medium))
        ActionEntry(letter:  "b", label: "(b)rowse shop", (m) => fm.planetsideController.shop(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.light))
        ActionEntry(letter:  "r", label:  "(r)epair ship", (m) => fm.planetsideController.enterMainRepairShop(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.medium))
        ActionEntry(letter:  "g", label:  "(g)enetic engineering", (m) => fm.planetsideController.bioHack(), exitAfter: false),
      if (planet.tier(planet.industry).atOrAbove(DistrictLvl.heavy))
        ActionEntry(letter:  "y", label:  "visit the ship(y)ard", (m) => fm.planetsideController.enterShipyard(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.heavy) && planet.tier(planet.population).atOrAbove(DistrictLvl.heavy))
        ActionEntry(letter:  "i", label: "broadcast (i)nformation about Star One", (m) => fm.planetsideController.broadcast(), exitAfter: false),
        ActionEntry(letter:  "l", label: "(l)aunch", (m) => fm.planetsideController.launch(), exitAfter: true),
    ];
  }

  Menu buildTavernMenu(SpaceEnvironment env) {
    return <MenuEntry> [
      TextEntry(txtBlocks: [TextBlock("Welcome to ${env.name}", GameColors.green, true)]),
      ActionEntry(letter: "c", label: "Enter the Cantina", (m) => mc.showMenu(() => buildCatinaMenu(env),level: MenuLevel.tavern)),
      ActionEntry(letter: "f", label: "Play Foohsam", (m) =>  mc.showMenu(() => buildFooshamIntroMenu(fm.player),level: MenuLevel.mainFoosham)),
    ];
  }

  Menu buildCatinaMenu(SpaceEnvironment env) {
    AlienDrink drink;
    double drinkStrength = fm.aiRng.nextDouble();
    if (env is Planet) {
      drink = env.drink = env.drink ?? DrinkGen.generate(fm.galaxy, env, fm.itemRng, strength: drinkStrength);
      drinkStrength = ((1-fm.galaxy.civKernel.val(fm.player.system)) + ((1-env.techLvl + env.industry)/2))/2;
    } else {
      drink = AlienDrink("Space Grog", desc: "Generic Space Station Grog", baseCost: 5, strength: drinkStrength, potency: "unknown");
    }
    //int drinkCost = 1 + (env.techLvl * 5).round();
    return <MenuEntry> [
      fm.player.creditLine,
      TextEntry(txtBlocks: [TextBlock("Grog's Cantina", GameColors.green, true)]),
      TextEntry(txtBlocks: [TextBlock("Happy Hour Special: ",GameColors.white, false), TextBlock(drink.name, drink.objColor, true)]),
      TextEntry(txtBlocks: [TextBlock("You are currently: ",GameColors.white, false), TextBlock(fm.player.inebriationLevel, GameColors.gray, true)]),
      ActionEntry(letter: "1", label: "Order a drink", (m) => fm.planetsideController.drink(1, drink, env)),
      ActionEntry(letter: "2", label: "Order a double", (m) => fm.planetsideController.drink(2, drink, env)),
    ];
  }

  Menu buildFooshamIntroMenu(Pilot pilot) {
    final game = FooShamGame(pilot.system,fm.aiRng, difficulty: FooShamDifficulty.medium, civMod: fm.galaxy.civMod);
    return <MenuEntry> [
      TextEntry(txtBlocks: [
        TextBlock("Welcome to Intergalactic Roshambo!", GameColors.green, true),
        TextBlock("You discover what beats what as the game evolves.", GameColors.green, true),
        TextBlock("Can you outwit the house?", GameColors.green, true),
      ]),
      ActionEntry(letter: "p",label: "(p)lay", (m) => mc.showMenu(() => buildFooshamMenu(pilot,game)))
    ];
  }

  Menu buildFooshamMenu(Pilot pilot, FooShamGame game) {
    return <MenuEntry> [
      TextEntry(txtBlocks: [TextBlock(game.currentScore(), GameColors.white, true)]),
      if (game.winner == null) for (int i = 0; i < game.throwList.length; i++)
        ValueEntry(letter: letter(i),
            txtBlocks: [TextBlock("${game.throwList[i]} ${game.beatInfo(game.throwList[i])}", GameColors.green, true)],
            game.throwList[i], (t) {
              final result = game.playThrow(t);
              fm.msg(result.toString());
              if (result.crowdReaction != null) fm.msg(result.crowdReaction!.message);
            })
    ];
  }

  Menu buildUninstallMenu(Ship ship) {
    final systems = ship.systemControl.getInstalledSystems().toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter: letter(i),label: "${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.msgController.addResultMsg(fm.pilotController.uninstallSystem(system, ship)),exitAfter: true)
    ];
  }

  Menu buildInstallMenu(Ship ship) {
    final systems = ship.systemControl.uninstalledSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter: letter(i), label: "${systems[i].name} , ${systems[i].slot}", systems[i],
                (system) => fm.pilotController.installSystem(ship, system),
            exitAfter: false, disabledReason: () => (ship.systemControl.availableSlotsbySystem(systems[i]).isEmpty
                ? "No available slot"
                : null))
    ];
  }

  Menu buildInstallSlotMenu(Ship ship, ShipSystem system) {
    final slots = ship.systemControl.availableSlotsbySystem(system).map((s) => s.slot).toList();
    return <MenuEntry> [
      for (int i = 0; i < slots.length; i++)
        ValueEntry(letter: letter(i), label: "${slots[i]}", slots[i],
                (slot) => fm.msgController.addResultMsg(fm.pilotController.installSystem(ship, system, slot: slot)), exitAfter: true)
    ];
  }

  Menu buildShopBuyMenu(Shop shop, {Ship? ship}) {
    final entries = <MenuEntry> [
      TextEntry(label: "Credits: ${fm.player.credits}"),
      for (int i = 0; i < shop.itemSlots.length; i++) slotEntry(shop.itemSlots.elementAt(i), letter(i), shop, ship)
    ];
    if (shop.type == ShopType.shipyard) {
      entries.add(ActionEntry(letter: "z", label: "enter hangar", (m) => mc.showMenu(() => buildHangarMenu(shop.location))));
    } else {
      entries.add(ActionEntry(letter: "s", label: "(s)ell", (m) => mc.showMenu(() => buildShopSellMenu(shop, ship: ship))));
    }
    return entries;
  }

  Menu buildHangarMenu(SpaceEnvironment shop) {
    return <MenuEntry> [
      for (int i = 0; i < shop.hangar.length; i++) ValueEntry(
          letter: letter(i),
          label: shop.hangar.elementAt(i).shopDesc,
          shop.hangar.elementAt(i),
              (m) => fm.newShip(fm.player, shop.hangar.elementAt(i)),exitAfter: true)
    ];
  }

  //TODO: make player inventory like shops?
  Menu buildShopSellMenu(Shop shop, {Ship? ship}) { //TODO: filter by shop type
    final installed = ship?.systemControl.getInstalledSystems() ?? [];
    final items = [
      ...ship?.inventory.where((i) => !installed.contains(i)) ?? [],
      ...ship?.scrapHeap ?? [],
    ];
    return <MenuEntry> [
      for (int i = 0; i < items.length; i++)
        ValueEntry(letter: letter(i), label: "${items[i].name} , ${items[i].baseCost}", items[i], //TODO: show cost modifier?
                (item) {
              fm.msgController.addMsg(shop.transactionBuy(item, ship: ship)); //createAndShowShopMenu(shop, ship, true); //refresh shop
            },exitAfter: true)
    ];
  }

  Menu buildHyperspaceMenu(System system) {
    return List.generate(system.links.length, (i) {
        final s = system.links.elementAt(i);
        String path = ((fm.playerShip?.itinerary ?? []).contains(s))
            ? " (${fm.playerShip!.itinerary!.length} to ${fm.playerShip!.itinerary!.last.name})"
            : "";
        return ActionEntry(letter: letter(i),
            txtBlocks: [TextBlock("${s.shortString(fm.galaxy)} $path",
                s.visited ? GameColors.gray : GameColors.green, true)],
                (m) => fm.layerTransitController
                    .newSystem(fm.player, system.links.elementAt(i)),exitAfter: true);
    });
  }

  Menu buildSystemToggleMenu(Ship ship) {
    final systems = ship.systemControl.getInstalledSystems();
    return List<MenuEntry>.generate(systems.length, (i) => ValueEntry(
        letter: fm.menuController.letter(i),
        label:systems.elementAt(i).name,
        systems.elementAt(i), (s) => fm.pilotController.toggleSystem(s, ship), exitAfter: true));
  }

  Menu buildMainRepairMenu(Ship ship) {
    return [
      TextEntry(label: "Credits: ${fm.player.credits}"),
      ActionEntry(letter: "h", label: "repair (h)ull", (m) => fm.planetsideController.enterRepairShop(ship)),
      ActionEntry(letter: "s", label: "repair (s)ystem", (m) => fm.planetsideController.enterSystemRepairShop(ship)),
    ];
  }

  Menu buildRepairMenu({required Ship ship, ShipSystem? sys}) {
    final desc = sys == null ? "hull" : sys.name;
    return [
      TextEntry(label: "Credits: ${fm.player.credits}"),
      sys == null
          ? TextEntry(label: "Hull Damage: ${ship.hullDamage.round()}")
          : TextEntry(label: "${sys.name} Damage: ${sys.dmgTxt}"),
      ActionEntry(letter: "1", label: "repair 1% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.01)
          : fm.planetsideController.tryHullRepair(ship,.01)),
      ActionEntry(letter: "5", label: "repair 5% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.05)
          : fm.planetsideController.tryHullRepair(ship,.05)),
      ActionEntry(letter: "t", label: "repair 10% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.1)
          : fm.planetsideController.tryHullRepair(ship,.1)),
      ActionEntry(letter: "q", label: "repair 25% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.25)
          : fm.planetsideController.tryHullRepair(ship,.25)),
      ActionEntry(letter: "h", label: "repair 50% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.5)
          : fm.planetsideController.tryHullRepair(ship,.5)),
      ActionEntry(letter: "a", label: "repair 100% of $desc", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,1)
          : fm.planetsideController.tryHullRepair(ship,1)),
    ];
  }

  Menu buildSystemRepairMenu(Ship ship) {
    List<ActionEntry> sysList = []; int i=0;
    for (final s in ship.systemControl.getInstalledSystems().where((sys) => sys.damage > 0)) {
      sysList.add(ActionEntry(letter: letter(i++), label: "${s.name}",
              (m) => fm.planetsideController.enterRepairShop(ship,sys: s)));
    }
    return sysList;
  }
}

