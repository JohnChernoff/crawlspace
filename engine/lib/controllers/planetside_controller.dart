import 'dart:math';

import 'package:crawlspace_engine/location.dart';
import 'package:crawlspace_engine/menu.dart';
import 'package:crawlspace_engine/object.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import '../agent.dart';
import '../audio_service.dart';
import '../descriptors.dart';
import '../foosham/foosham.dart';
import '../foosham/throws.dart';
import '../pilot.dart';
import '../planet.dart';
import '../player.dart';
import '../rng.dart';
import '../sector.dart';
import '../ship.dart';
import '../shop.dart';
import '../galaxy/system.dart';
import '../systems/ship_system.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class PlanetsideController extends FugueController {
  PlanetsideController(super.fm);

  void planetFall() {
    Ship? ship = fm.playerShip; if (ship == null) {
      fm.msgController.addMsg("No ship!"); return;
    }
    final cell = ship.loc.cell; if (cell is! SectorCell) {
      fm.msgController.addMsg("Wrong layer!"); return;
    }
    final planet = cell.planet; if (planet == null) {
      fm.msgController.addMsg("No planet!"); return;
    }
    fm.player.locale = AtEnvironment(planet);
    if (fm.pilotController.action(fm.player,ActionType.planetLand)) {
      if (planet.loc.level.homeworld == StockSpecies.humanoid.species) {
        fm.homecoming(home: true);
      } else {
        fm.menuController.showPlanetMenu(planet);
        fm.audioController.newTrack(newMood: MusicalMood.planet);
        fm.msgController.addMsg("Landing on ${planet.name}");
        fm.msgController.addMsg(planet.description ?? "What a dump");
        if (fm.player.tradeTarget?.location == planet) {
          fm.msgController.addMsg(
              "You deliver your cargo.  Reward: ${fm.player.tradeTarget
                  ?.reward}");
          fm.player.credits += fm.player.tradeTarget?.reward ?? 0;
          fm.player.tradeTarget = null;
        }
      }
    }
  }

  void launch() {  //fm.menuController.exitMenu();
    if (fm.playerShip != null) fm.player.locale = AboardShip(fm.playerShip!);
    fm.msgController.addMsg("Launching...");
    fm.audioController.newTrack(newMood: MusicalMood.space);
    fm.pilotController.action(fm.player,ActionType.planetLaunch);
  }

  void broadcast() {
    if (!fm.player.starOne) {
      fm.msgController.addMsg("You must first find Star One.");
    }
    else if (fm.player.credits < fm.shopOptions.costBroadcast) {
      fm.msgController.addMsg("You can't afford this (${fm.shopOptions.costBroadcast} credits).");
    } else {
      fm.msgController.addMsg("You broadcast a message of insurrection against the Galactic Federation");
      fm.player.broadcasts++;
      fm.player.credits -= fm.shopOptions.costBroadcast;
      propaganda(fm.player.system, 0, 4, {fm.player.system});
    }
  }

  void propaganda(System system, int level, int depth, Set<System> systems) {
    fm.msgController.addMsg("Undermining system: ${system.name}");
    if (level < depth) {
      //system.fed = (system.fed / (depth - level)).floor(); TODO: update fed levels
      for (System link in system.links) {
        if (systems.add(link)) {
          propaganda(link, level + 1, depth, systems);
        }
      }
    }
    fm.heat(25,sighted: fm.player.system);
  }

  void getTradeMission() {
    if (fm.playerShip == null) {
      fm.msgController.addMsg("You're not in a ship!");
    } else if (fm.player.tradeTarget?.source == fm.player.locale) {
      fm.msgController.addMsg("You already have a mission from this planet.");
    } else {
      List<System> path = [];
      int steps = 3;
      int r = 100; //(player.techLevel() / 10).ceil() * playerShip!.cargo.value;
      int reward = (r/2).floor() + fm.rnd.nextInt(r);
      Planet? planet; int tries = 0;
      while (planet == null && tries++ < 100) {
        path = [fm.player.system];
        planet = createTradePlanet(path, steps);
      }
      if (planet != null && fm.player.locale is SpaceEnvironment) {
        fm.player.tradeTarget = TradeTarget(planet, fm.player.locale as SpaceEnvironment, reward);
        fm.msgController.addMsg("${planet.name} is in desperate need of ${rndEnum(Goods.values.where((g) => g != planet?.export))}, "
            "reward: $reward. Route: ${fm.pathList(path)}");
      } else {
        fm.msgController.addMsg("Failed to find planet in route: ${fm.pathList(path)}");
      }
      fm.pilotController.action(fm.player,ActionType.planet, mod: 1.25);
    }
  }

  void spy() {
    for (Agent agent in fm.agents) {
      if (agent.tracked == 0) {
        agent.track((fm.player.techLevel(fm.galaxy) / 8).floor() * (fm.techCheck(1) ? 2 : 1));
        List<System> path = fm.galaxy.topo.graph.shortestPath(fm.player.system, agent.system);
        fm.msgController.addMsg("${agent.name} is ${fm.jumps(path)} jumps away (tracking for ${agent.tracked} jumps)");
      }
    }
    fm.pilotController.action(fm.player,ActionType.planet);
  }

  void hack() { //find starOne
    List<System> path = fm.galaxy.topo.graph.shortestPath(fm.player.system, fm.starOne());
    fm.msgController.addMsg("Star One is ${fm.jumps(path)} jumps away");
    fm.msgController.addMsg("Next step: ${fm.nextSystemInPath(path)?.name}");
    fm.pilotController.action(fm.player,ActionType.planet,mod: 1.5);
  }

  void scout() {
    int depth = (fm.player.techLevel(fm.galaxy) / 16).ceil();
    fm.msgController.addMsg("Scouting nearby systems (depth: $depth)...");
    fm.player.system.explore(depth);
    fm.pilotController.action(fm.player,ActionType.planet);
  }

  void bioHack({int amount = 1}) {
    if (fm.player.dnaScram < Player.maxDna) {
      if (fm.player.credits >= fm.shopOptions.costBioHack) {
        fm.player.credits -= fm.shopOptions.costBioHack;
        fm.player.dnaScram++;
        fm.msgController.addMsg("Dna scrambled (mutation: ${fm.player.dnaScram})");
        fm.pilotController.action(fm.player,ActionType.planet,mod: 2);
      } else {
        fm.msgController.addMsg("You can't afford this (cost: ${fm.shopOptions.costBioHack} credits).");
      }
    } else {
      fm.msgController.addMsg("Your system cannot handle further modification.");
    }
  }

  void shop({ShopType? type, List<Ship>? shiplist}) {
    final location = fm.player.locale; if (location is AtEnvironment) {
      if (type != null) {
        location.env.shop ??= Shop(location.env,type,1,fm.rnd);
      } else {
        location.env.shop ??= Shop.random(location.env,1,fm.rnd);
      }
      fm.menuController.showMenu(() => fm.menuController.createShopBuyMenu(location.env.shop!, ship: fm.playerShip),
          headerTxt: "${location.env.shop!.name}");
    }
  }

  void newFooShamGame(ThrowList list) {
    Pilot? pilot = fm.playerShip?.pilot;
    if (pilot != null) {
      final fooShamGame = FooShamGame(ThrowList.rndList(fm.rnd),fm.rnd, difficulty: FooShamDifficulty.medium);
      fm.menuController.showMenu(() => fm.menuController.createThrowMenu(pilot, fooShamGame));
    }
  }

  Planet? createTradePlanet(List<System> path,int steps) {
    if (steps < 1 && path.last.planets.isNotEmpty) {
      return path.last.planets.elementAt(fm.mapRng.nextInt(path.last.planets.length));
    } else {
      Set<System> links = path.last.links;
      List<System> unvisitedLinks = links.where((link) => !path.contains(link)).toList();
      if (unvisitedLinks.isNotEmpty) {
        unvisitedLinks.shuffle();
        path.add(unvisitedLinks.first);
        return createTradePlanet(path, steps-1);
      } else { //print("Trade error, steps: $steps, path: $path");
        return null;
      }
    }
  }

  void enterShipyard() {
    final loc = fm.player.locale; if (loc is AtEnvironment) {
      loc.env.yard ??= Shop(loc.env, ShopType.shipyard, 1, fm.rnd,
          shiplist: List.generate(fm.itemRng.nextInt(5) + 1, (i) =>
              Rng.generateShip(fm.player.system, fm.galaxy, fm.itemRng)));
      fm.menuController.showMenu(() =>
          fm.menuController.createShopBuyMenu(loc.env.yard!, ship: fm.playerShip), headerTxt: "${loc.env.yard!.name}");
    }
  }

  void enterRepairShop() {
    Ship? ship = fm.playerShip; if (ship == null) return;
    fm.menuController.showMenu(() => [
      TextEntry("Credits: ${fm.player.credits}"),
      ActionEntry("h", "repair (h)ull", (m) => enterMainRepairShop(ship)),
      ActionEntry("s", "repair (s)ystem", (m) => enterSystemRepairShop(ship)),
    ],headerTxt: "Repair Shop");
  }

  void enterMainRepairShop(Ship ship, {ShipSystem? sys}) {
    fm.menuController.showMenu(() => createRepairMenu(ship: ship,sys: sys), headerTxt: "Repair %");
  }

  List<MenuEntry> createRepairMenu({required Ship ship, ShipSystem? sys}) {
    final desc = sys == null ? "hull" : sys.name;
    return [
      TextEntry("Credits: ${fm.player.credits}"),
      sys == null ? TextEntry("Hull Damage: ${ship.hullDamage.round()}") : TextEntry("${sys.name} Damage: ${sys.dmgTxt}"),
      ActionEntry("1", "repair 1% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,.01) : tryHullRepair(ship,.01)),
      ActionEntry("5", "repair 5% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,.05) : tryHullRepair(ship,.05)),
      ActionEntry("t", "repair 10% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,.1) : tryHullRepair(ship,.1)),
      ActionEntry("q", "repair 25% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,.25) : tryHullRepair(ship,.25)),
      ActionEntry("h", "repair 50% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,.5) : tryHullRepair(ship,.5)),
      ActionEntry("a", "repair 100% of $desc", (m) => sys != null ? trySystemRepair(ship,sys,1) : tryHullRepair(ship,1)),
    ];
  }

  List<MenuEntry> createSystemRepairMenu(Ship ship) {
    List<ActionEntry> sysList = []; int i=0;
    for (final s in ship.getInstalledSystems().where((sys) => sys.damage > 0)) {
      sysList.add(ActionEntry(fm.menuController.letter(i++), "${s.name}", (m) => enterMainRepairShop(ship,sys: s)));
    }
    return sysList;
  }

  void enterSystemRepairShop(Ship ship) {
    fm.menuController.showMenu(() => createSystemRepairMenu(ship), headerTxt: "Pick System");
  }

  void tryHullRepair(Ship ship, double percent, {double discount = 1}) {
    int repairing = (ship.hullDamage * percent).round();
    int cost = (repairing * ship.hullType.baseRepairCost).round(); //TODO: add hull mods
    if (fm.player.transaction(TransactionType.repair, -cost)) {
      ship.hullDamage -= repairing;
      fm.msgController.addMsg("Repaired $repairing damage ($cost credits)");
    } else {
      fm.msgController.addMsg("Sorry, you can't afford that.");
    }
    fm.menuController.replaceTopMenuFull(() => createRepairMenu(ship: ship));
  }

  void trySystemRepair(Ship ship, ShipSystem system, double percent, {double discount = 1}) {
    double repairing = min(system.damage,percent);
    int cost = ((repairing  * 100) *  system.baseRepairCost).round(); //TODO: add system mods
    if (fm.player.transaction(TransactionType.repair, -cost)) {
      system.repair(percent);
      fm.msgController.addMsg("Repaired ${(repairing * 100).round()}% damage ($cost credits)");
    } else {
      fm.msgController.addMsg("Sorry, you can't afford that.");
    }
    fm.menuController.replaceTopMenuFull(() => createRepairMenu(ship: ship, sys: system));
  }

}