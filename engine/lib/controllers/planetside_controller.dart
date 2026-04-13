import 'dart:math';
import 'package:crawlspace_engine/rng/drinks_gen.dart';
import 'package:crawlspace_engine/galaxy/geometry/location.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/geometry/impulse.dart';
import 'package:crawlspace_engine/rng/ship_gen.dart';
import 'package:crawlspace_engine/stock_items/species.dart';
import 'package:crawlspace_engine/stock_items/ship/stock_pile.dart';
import '../actors/agent.dart';
import '../audio_service.dart';
import '../rng/descriptors.dart';
import '../menu.dart';
import '../actors/pilot.dart';
import '../galaxy/planet.dart';
import '../actors/player.dart';
import '../rng/rng.dart';
import '../ship/ship.dart';
import '../shop.dart';
import '../galaxy/system.dart';
import '../ship/systems/ship_system.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class PlanetsideController extends FugueController {
  PlanetsideController(super.fm);

  void planetFall() {
    Ship? ship = fm.playerShip; if (ship == null) {
      fm.msg("No ship!"); return;
    }
    final cell = ship.loc.cell;
    if (cell is ImpulseCell) {
      final planet = cell.getPlanet(fm.galaxy); 
      if (planet == null) {
        fm.msg("No planet!"); return;
      } //else if (ship.nav.moving) {fm.msg("Slow down first!"); return; }
      ship.nav.resetMotionState();
      fm.player.locale = AtEnvironment(planet);
      if (fm.pilotController.action(fm.player,ActionType.planetLand)) {
        if (planet.homeworld && planet.species == StockSpecies.humanoid.species) {
          fm.homecoming(home: true);
        } else {
          fm.menuController.showMenu(() => fm.menuFactory.buildPlanetMenu(planet),
              level: MenuLevel.planet, headerTxt: planet.name, noExit: true);
          fm.audioController.newTrack(newMood: MusicalMood.planet);
          fm.msg("Landing on ${planet.name}");
          //fm.msg(planet.shortDesc ?? "What a dump");
          if (fm.player.tradeTarget?.destination == planet) {
            fm.msg(
                "You deliver your cargo.  Reward: ${fm.player.tradeTarget
                    ?.reward}");
            fm.player.credits += fm.player.tradeTarget?.reward ?? 0;
            fm.player.tradeTarget = null;
          }
        }
      }
    } else {
      fm.msg("Wrong layer!"); return;
    }
  }

  void launch() {  //fm.menuController.exitMenu();
    if (fm.playerShip != null) fm.player.locale = AboardShip(fm.playerShip!);
    fm.msg("Launching...");
    fm.audioController.newTrack(newMood: MusicalMood.space);
    fm.pilotController.action(fm.player,ActionType.planetLaunch);
  }

  void broadcast() {
    if (!fm.player.starOne) {
      fm.msg("You must first find Star One.");
    }
    else if (fm.player.credits < fm.shopSettings.costBroadcast) {
      fm.msg("You can't afford this (${fm.shopSettings.costBroadcast} credits).");
    } else {
      fm.msg("You broadcast a message of insurrection against the Galactic Federation");
      fm.player.broadcasts++;
      fm.player.credits -= fm.shopSettings.costBroadcast;
      propaganda(fm.player.system, 0, 4, {fm.player.system});
    }
  }

  void propaganda(System system, int level, int depth, Set<System> systems) {
    fm.msg("Undermining system: ${system.name}");
    if (level < depth) {
      //system.fed = (system.fed / (depth - level)).floor(); TODO: update fed levels
      for (System link in system.links) {
        if (systems.add(link)) {
          propaganda(link, level + 1, depth, systems);
        }
      }
    }
    //fm.heat(25,sighted: fm.player.system);
  }

  void getTradeMission() {
    final pLoc = fm.player.locale;
    if (pLoc is! AtEnvironment) return;
    if (fm.playerShip == null) {
      fm.msg("You lack a ship!");
    } else if (fm.player.tradeTarget?.source == pLoc.env) {
      fm.msg("You already have a mission from this planet.");
    } else {
      List<System> path = [];
      int steps = 3;
      int r = 100; //(player.techLevel() / 10).ceil() * playerShip!.cargo.value;
      int reward = (r/2).floor() + fm.itemRnd.nextInt(r);
      Planet? planet; int tries = 0;
      while (planet == null && tries++ < 100) {
        path = [fm.player.system];
        planet = createTradePlanet(path, steps);
        print("Try $tries: path=${path.map((s) => s.name).join('->')}, planet=$planet");
      }
       if (planet != null) {
        fm.player.tradeTarget = TradeTarget(planet, pLoc.env, reward);
        fm.msg("${planet.name} is in desperate need of ${rndEnum(Goods.values.where((g) => g != planet?.export))}, "
            "reward: $reward. Route: ${fm.pathList(path)}");
      } else {
        fm.msg("Failed to find planet in route: ${fm.pathList(path)}");
      }
      fm.pilotController.action(fm.player,ActionType.planet, mod: 1.25);
    }
  }

  void spy() {
    for (Agent agent in fm.agents) {
      if (agent.tracked == 0) {
        agent.tracked = ((fm.player.techLevel(fm.galaxy) / 8).floor() * (fm.techCheck(1) ? 2 : 1));
        List<System> path = fm.galaxy.topo.graph.shortestPath(fm.player.system, agent.system);
        fm.msg("${agent.name} is ${fm.jumps(path)} jumps away (tracking for ${agent.tracked} jumps)");
      }
    }
    fm.pilotController.action(fm.player,ActionType.planet);
  }

  void hack() { //find starOne
    List<System> path = fm.galaxy.topo.graph.shortestPath(fm.player.system, fm.starOne());
    fm.msg("Star One is ${fm.jumps(path)} jumps away");
    fm.msg("Next step: ${fm.nextSystemInPath(path)?.name}");
    fm.pilotController.action(fm.player,ActionType.planet,mod: 1.5);
  }

  void scout() {
    int depth = (fm.player.techLevel(fm.galaxy) / 16).ceil();
    fm.msg("Scouting nearby systems (depth: $depth)...");
    fm.player.system.explore(depth,fm.galaxy);
    fm.pilotController.action(fm.player,ActionType.planet);
  }

  void bioHack({int amount = 1}) {
    if (fm.player.dnaScram < Player.maxDna) {
      if (fm.player.credits >= fm.shopSettings.costBioHack) {
        fm.player.credits -= fm.shopSettings.costBioHack;
        fm.player.dnaScram++;
        fm.msg("Dna scrambled (mutation: ${fm.player.dnaScram})");
        fm.pilotController.action(fm.player,ActionType.planet,mod: 2);
      } else {
        fm.msg("You can't afford this (cost: ${fm.shopSettings.costBioHack} credits).");
      }
    } else {
      fm.msg("Your system cannot handle further modification.");
    }
  }

  void market() {
    final location = fm.player.locale; if (location is AtEnvironment) {
      final env = location.env;
      env.market ??= Market(env as Planet, fm.galaxy, fm.itemRnd);
      fm.menuController.showMenu(() => fm.menuFactory.buildShopBuyMenu(env.market!, ship: fm.playerShip),
          headerTxt: "${env.market?.name}");
    }
  }

  void systemShop({SystemShopType? type}) { //, List<Ship>? shiplist
    final location = fm.player.locale; if (location is AtEnvironment) {
      final env = location.env;
      final techLvl = (env is Planet && env.homeworld)
          ? (maxTechLvl * env.techLvl).round()
          : (fm.itemRnd.nextDouble() * (maxTechLvl * env.techLvl)).round();
      if (type != null) {
        env.sysShop ??= SystemShop(env,type,techLvl,fm.itemRnd, galaxy: fm.galaxy);
      } else {
        env.sysShop ??= SystemShop.random(env,techLvl,fm.itemRnd, galaxy: fm.galaxy);
      }
      fm.menuController.showMenu(() => fm.menuFactory.buildShopBuyMenu(env.sysShop!, ship: fm.playerShip),
          headerTxt: "${env.sysShop?.name}");
    }
  }

  void drink(int pints, AlienDrink drink, SpaceEnvironment env) {
    if (!fm.player.transaction(TransactionType.drink, -drink.baseCost)) {
      fm.msg("You can't afford a drink!"); return;
    }
    final cost = drink.baseCost * pints;
    final strength = drink.strength * pints;
    fm.msg("You pay ${cost} credits.");
    fm.player.drink(strength);
    double charChk = fm.player.attributes[AttribType.cha]! / 3;
    //print("Drink Strength: $strength"); print("Char Check: $charChk");
    if (fm.aiRnd.nextDouble() < charChk) {
      env.rapport += .1 * strength;
      fm.msg(switch(env.rapport) {
        > .8 => "The locals love you!",
        > .5 => "The locals seem to like you a lot.",
        > .2 => "The locals seem to like you a bit better.",
        _ => "Glurg..."
      });
    }
    if (fm.aiRnd.nextDouble() < .25) { //(env.rapport * .1)) { //TODO: debug settings
      final nearestItem = fm.galaxy.items.nearestItem(fm.player.system, fm.galaxy);
      fm.msg("Psst - there's treasure at ${nearestItem.key}");
    }
    final security = env is Planet ? (env.population + env.fedLvl) / 2.0 : 0.5;
    final conResistance = fm.player.attributes[AttribType.con]! * 0.5;
    final blackoutChance = (fm.player.inebriation - conResistance).clamp(0.0, 1.0);
    if (fm.aiRnd.nextDouble() < blackoutChance) {
      fm.player.inebriation = 0;
      final robChance  = 1.0 - security;
      final fedChance  = security;
      final totalChance = robChance + fedChance;
      final roll = fm.aiRnd.nextDouble() * totalChance;
      if (roll < robChance) {
        // Robbed — lawless outcome
        final stolen = (fm.player.credits * (0.1 + fm.aiRnd.nextDouble() * 0.3)).round();
        fm.player.transaction(TransactionType.robbed, -stolen);
        fm.msg("You wake up in an alley. Your pockets are lighter by $stolen credits.");
      } else {
        // Arrested — security outcome
        fm.player.transaction(TransactionType.jail, -1000);
        fm.msg("You pass out and are taken to the local jail to sleep it off. Processing fee: 1000 credits.");
        //heat calc
        if (fm.aiRnd.nextDouble() < env.fedLvl) {
          fm.galaxy.playerCrime(fm.player.system, env.fedLvl * 5);
          fm.msg(switch(env.fedLvl) {
            > .75 => "The authorities file a full report. The Feds will know you were here.",
            > .4  => "The local constable logs your name. Someone might be watching.",
            _     => "Word of your arrest spreads through the cantina...",
          });
        }
      }
      fm.menuController.exitToLevel(MenuLevel.planet);
    }
  }

  Planet? createTradePlanet(List<System> path,int steps) {
    if (steps < 1 && path.last.planets(fm.galaxy).isNotEmpty) {
      return path.last.planets(fm.galaxy).elementAt(fm.mapRnd.nextInt(path.last.planets(fm.galaxy).length));
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
    final locale = fm.player.locale; if (locale is AtEnvironment) {
      if (locale.env.yard == null) {
        final owner = Pilot(Rng.generateName(rnd: fm.itemRnd),locale, rnd: fm.itemRnd,  galaxy: fm.galaxy, isPirate: false);
        final n = fm.itemRnd.nextInt(5) + 1;
        for (int i=0;i<n;i++) {
          final ship = ShipGenerator.generateShip(fm.player.system, fm.galaxy, fm.itemRnd, owner: owner);
          fm.galaxy.ships.addDocked(ship,locale.env);
          ShipGenerator.installRandomSystems(ship, fm.itemRnd);
        }
        locale.env.yard = ShipYard(locale.env, 1, fm.itemRnd,fm.galaxy);
      }
      fm.menuController.showMenu(() =>
          fm.menuFactory.buildShopBuyMenu(locale.env.yard!, ship: fm.playerShip), headerTxt: "${locale.env.yard!.name}");
    }
  }

  void enterMainRepairShop() {
    Ship? ship = fm.playerShip; if (ship == null) return;
    fm.menuController.showMenu(() => fm.menuFactory.buildMainRepairMenu(ship),headerTxt: "Repair Shop");
  }

  void enterRepairShop(Ship ship, {ShipSystem? sys}) {
    fm.menuController.showMenu(() => fm.menuFactory.buildRepairMenu(ship: ship,sys: sys), headerTxt: "Repair %");
  }

  void enterSystemRepairShop(Ship ship) {
    fm.menuController.showMenu(() => fm.menuFactory.buildSystemRepairMenu(ship), headerTxt: "Pick System");
  }

  int tryHullRepair(Ship ship, double percent, {double discount = 1, dryRun = false}) {
    int repairing = (ship.hullDamage * percent).round();
    int cost = (repairing * ship.hull.material.baseRepairCost * discount).round(); //TODO: add hull mods
    if (!dryRun) {
      if (fm.player.transaction(TransactionType.repair, -cost)) {
        ship.hullDamage -= repairing;
        fm.msg("Repaired $repairing damage ($cost credits)");
      } else {
        fm.msg("Sorry, you can't afford that.");
      }
    }
    return cost;
  }

  int trySystemRepair(Ship ship, ShipSystem system, double percent, {double discount = 1, dryRun = false}) {
    double repairing = min(system.damage,percent);
    int cost = ((repairing  * 100) *  system.baseRepairCost * discount).round(); //TODO: add system mods
    if (!dryRun) {
      if (fm.player.transaction(TransactionType.repair, -cost)) {
        system.repair(percent);
        fm.msg("Repaired ${(repairing * 100).round()}% damage ($cost credits)");
      } else {
        fm.msg("Sorry, you can't afford that.");
      }
    }
    return cost;
  }

}