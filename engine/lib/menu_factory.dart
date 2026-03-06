import 'package:crawlspace_engine/color.dart';
import 'package:crawlspace_engine/controllers/menu_controller.dart';
import 'package:crawlspace_engine/item.dart';
import 'package:crawlspace_engine/rng/drinks.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import 'package:crawlspace_engine/pilot.dart';
import 'package:crawlspace_engine/planet.dart';
import 'package:crawlspace_engine/ship.dart';
import 'package:crawlspace_engine/shop.dart';
import 'package:crawlspace_engine/stock_items/xenomancy.dart';
import 'package:crawlspace_engine/systems/ship_system.dart';
import 'foosham/foosham_session.dart';
import 'galaxy/system.dart';
import 'menu.dart';
import 'object.dart';

typedef Menu = List<MenuEntry>;

class MenuFactory {
  final FugueEngine fm;
  MenuController get mc => fm.menuController;
  String letter(int i) => mc.letter(i);
  const MenuFactory(this.fm);

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

  Menu buildXenoMenu(Pilot pilot, {void Function(XenomancySpell spell)? action}) {
    return List.generate(pilot.knownSpells.length,(i) {
      final spell = pilot.knownSpells.entries.elementAt(i);
      final ship = fm.shipRegistry.byPilot(pilot);
      final chance = ship?.xenoControl.effectProb(spell.value) ?? 0;
      final power = ship?.xenoControl.calcPower(spell.value) ?? 0;
      final noMatter = spell.value.matterCost > (ship?.xenoMatter ?? 0);
      final blocks = [
        TextBlock(spell.value.spellName, GameColors.white, false),
        TextBlock(", ${spell.value.matterCost} xm ", GameColors.white, false),
        TextBlock("(${(power * 100).round()}%) ", GameColors.green, false),
        TextBlock("(${(chance * 100).round()}%) ", GameColors.neonBlue, !noMatter)
      ];
      if (action != null) return ValueEntry(letter: spell.key, txtBlocks: blocks, spell.value, action, exitBefore: true,
          disabledReason: () => noMatter ? "Insufficient Xeno Matter" : null
      );
      else return TextEntry(txtBlocks: blocks);
    });
  }

  Menu buildInventoryMenu(InventoryView view, {shop = true, void Function(Item item)? action}) { //print("Inventory: ${ship.allInventory}");
    final items = view.items;
    return List.generate(items.slots.length,(i) {
      final slot = items.slots.elementAt(i);
      print ("Inventory slot: ${slot.slotName}");
      if (action != null) return ValueEntry(letter: mc.letter(i), label: slot.label(shop: shop), slot.item, (m) => action(m));
      else return TextEntry(label: slot.label(shop: shop));
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
        ActionEntry(letter:  "b", label: "(b)rowse shop", (m) => fm.planetsideController.systemShop(), exitAfter: false),
      if (planet.tier(planet.commerce).atOrAbove(DistrictLvl.medium)) //&& planet.tier(planet.industry).atOrAbove(DistrictLvl.medium))
        ActionEntry(letter:  "m", label: "visit the (m)arket", (m) => fm.planetsideController.market(), exitAfter: false),
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
    return <MenuEntry> [
      fm.player.creditLine,
      TextEntry(txtBlocks: [TextBlock("Grog's Cantina", GameColors.green, true)]),
      TextEntry(txtBlocks: [TextBlock("Happy Hour Special: ",GameColors.white, false), TextBlock(drink.name, drink.objColor, true)]),
      TextEntry(txtBlocks: [TextBlock("You are currently: ",GameColors.white, false), TextBlock(fm.player.inebriationLevel, GameColors.gray, true)]),
      ActionEntry(letter: "1", label: "Order a drink", (m) => fm.planetsideController.drink(1, drink, env)),
      ActionEntry(letter: "2", label: "Order a double", (m) => fm.planetsideController.drink(2, drink, env)),
    ];
  }

  Menu buildFooshamIntroMenu(Pilot pilot) { //print("Env: ${pilot.tech}");
    final stakes = (pilot.tech * 1000).round();
    return <MenuEntry> [
      fm.player.creditLine,
      TextEntry(txtBlocks: [
        TextBlock("Welcome to Intergalactic Roshambo!", GameColors.green, true),
        TextBlock("You discover what beats what as the game evolves.", GameColors.green, true),
        TextBlock("Can you outwit the house (entry fee: $stakes cr)?", GameColors.green, true),
      ]),
      ActionEntry(letter: "p",label: "(p)lay", (m) {
        if (pilot.transaction(TransactionType.fooshamPlay, -stakes)) {
          fm.msg("You enter the foosham tables and pay $stakes credits.  Good luck!");
          final session = FooshamSession(pilot, stakes, fm);
          mc.showMenu(() => buildFooshamMenu(pilot,session), noExit: true);
        } else {
          fm.msg("You can't afford it!");
        }
      })
    ];
  }

  Menu buildFooshamMenu(Pilot pilot, FooshamSession fooSession) {
    final game = fooSession.game;
    final exitLabel= fooSession.gameOver
        ? "e(x)it table"
        : "e(x)it table (forfeit ${fooSession.stakes} credits)";
    return <MenuEntry> [
      TextEntry(txtBlocks: [TextBlock(game.currentScore(), GameColors.white, true)]),
      if (!fooSession.gameOver) for (int i = 0; i < game.throwList.length; i++)
        ValueEntry(letter: letter(i),
            txtBlocks: [TextBlock("${game.throwList[i]} ${game.beatInfo(game.throwList[i])}", GameColors.green, true)],
            game.throwList[i], (t) => fooSession.gameThrow(t)),
      ActionEntry(letter: "x", label: exitLabel, (m) {
        fooSession.gameOver = true;
        m.exitMenu();
      }),
    ];
  }

  Menu buildUninstallMenu(Ship ship) {
    final systems = ship.systemControl.getInstalledSystems().toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter: letter(i),label: systems[i].toString(), systems[i],
                (system) => fm.msgController.addResultMsg(fm.pilotController.uninstallSystem(system, ship)),exitAfter: true)
    ];
  }

  Menu buildInstallMenu(Ship ship) {
    final systems = ship.systemControl.uninstalledSystems.toList();
    return <MenuEntry> [
      for (int i = 0; i < systems.length; i++)
        ValueEntry(letter: letter(i), label: systems[i].toString(), systems[i],
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
        ValueEntry(letter: letter(i), label: "${slots[i].labelFor(system)}", slots[i],
                (slot) => fm.msgController.addResultMsg(fm.pilotController.installSystem(ship, system, slot: slot)), exitAfter: true)
    ];
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

  Menu buildShopBuyMenu(Shop shop, {Ship? ship}) {
    final pilot = ship?.pilot ?? fm.player;
    final menu = buildInventoryMenu(shop.inventory,action: (i) => fm.msg(shop.transactionSell(i, ship: ship)));
    menu.insert(0, pilot.creditLine);
    if (shop is Market) menu.insert(1, TextEntry(label: "Buying: ${shop.buyListSummary()}"));
    if (shop is ShipYard) {                              // ← changed
      menu.add(ActionEntry(
          letter: "z",
          label: "enter hangar",
              (m) => mc.showMenu(() => buildHangarMenu(shop.location))));
    } else if (ship != null) {
      menu.add(ActionEntry(
          letter: "s",
          label: "(s)ell",
              (m) => mc.showMenu(() => buildShopSellMenu(shop, ship: ship))));
    }
    return menu;
  }

  Menu buildShopSellMenu(Shop shop, {required Ship ship}) {
    // Markets only accept items on their buy list
    final items = (shop is Market)
        ? ship.cargo.filterType<Item>().filter((i) => shop.canBuy(i))
        : ship.cargo;

    final menu = buildInventoryMenu(items,action: (i) => fm.msgController.addMsg(
        shop.transactionBuy(i, ship: ship)));

    return <MenuEntry>[
      if (shop is Market && items.isEmpty)
        TextEntry(label: "The market isn't interested in anything you're carrying."),
      ...menu,
    ];
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
    double discount = (1-ship.pilot.tech) * 5;
    repairCost(double percent) => (sys == null
        ? fm.planetsideController.tryHullRepair(ship, percent,discount: discount,dryRun: true)
        : fm.planetsideController.trySystemRepair(ship, sys, percent, discount: discount, dryRun: true));
    strCost(double percent) => "(${repairCost(percent)}cr)";
    return [
      ship.pilot.creditLine,
      sys == null
          ? TextEntry(label: "Hull Damage: ${ship.hullDamage.round()}")
          : TextEntry(label: "${sys.name} Damage: ${sys.dmgTxt}"),
      ActionEntry(letter: "1", label: "repair 1% of $desc ${strCost(.01)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.01,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,.01,discount: discount)),
      ActionEntry(letter: "5", label: "repair 5% of $desc ${strCost(.05)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.05,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,.05,discount: discount)),
      ActionEntry(letter: "t", label: "repair 10% of $desc ${strCost(.1)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.1,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,.1,discount: discount)),
      ActionEntry(letter: "q", label: "repair 25% of $desc ${strCost(.25)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.25,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,.25,discount: discount)),
      ActionEntry(letter: "h", label: "repair 50% of $desc ${strCost(.5)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,.5,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,.5,discount: discount)),
      ActionEntry(letter: "a", label: "repair 100% of $desc ${strCost(1)}", (m) => sys != null
          ? fm.planetsideController.trySystemRepair(ship,sys,1,discount: discount)
          : fm.planetsideController.tryHullRepair(ship,1,discount: discount)),
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

