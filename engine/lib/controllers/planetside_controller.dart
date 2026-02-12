import '../agent.dart';
import '../audio_service.dart';
import '../descriptors.dart';
import '../foosham/foosham.dart';
import '../foosham/throws.dart';
import '../pilot.dart';
import '../planet.dart';
import '../player.dart';
import '../ship.dart';
import '../shop.dart';
import '../system.dart';
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
    final planet = fm.player.planet = cell.planet; if (planet == null) {
      fm.msgController.addMsg("No planet!"); return;
    }

    if (planet == fm.galaxy.homeWorld) {
      fm.endGame("You complete your mission!",home: true);
    } else {
      fm.menuController.showPlanetMenu(planet);
      fm.audioController.newTrack(newMood: MusicalMood.planet);
      fm.pilotController.action(fm.player,ActionType.planetLand);
      fm.msgController.addMsg("Landing on ${planet.name}");
      fm.msgController.addMsg(planet.description);
      if (fm.player.tradeTarget?.planet == planet) {
        fm.msgController.addMsg(
            "You deliver your cargo.  Reward: ${fm.player.tradeTarget
                ?.reward}");
        fm.player.credits += fm.player.tradeTarget?.reward ?? 0;
        fm.player.tradeTarget = null;
      }
    }
  }

  void launch() {
    fm.player.planet = null;
    fm.menuController.exitInputMode();
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
      system.fedLvl = (system.fedLvl / (depth - level)).floor();
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
    } else if (fm.player.tradeTarget?.source == fm.player.planet) {
      fm.msgController.addMsg("You already have a mission from this planet.");
    } else {
      List<System> path = [];
      int steps = 3;
      int r = 100; //(player.techLevel() / 10).ceil() * playerShip!.cargo.value;
      int reward = (r/2).floor() + fm.rnd.nextInt(r);
      Planet? planet; int tries = 0;
      while (planet == null && tries++ < 100) {
        path = [fm.player.system];
        planet = fm.createTradePlanet(path, steps);
      }
      if (planet != null) {
        fm.player.tradeTarget = TradeTarget(planet, fm.player.planet, reward);
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
        agent.track((fm.player.techLevel() / 8).floor() * (fm.techCheck(1) ? 2 : 1));
        List<System> path = fm.systemGraph.shortestPath(fm.player.system, agent.system);
        fm.msgController.addMsg("${agent.name} is ${fm.jumps(path)} jumps away (tracking for ${agent.tracked} jumps)");
      }
    }
    fm.pilotController.action(fm.player,ActionType.planet);
  }

  void hack() { //find starOne
    List<System> path = fm.systemGraph.shortestPath(fm.player.system, fm.starOne());
    fm.msgController.addMsg("Star One is ${fm.jumps(path)} jumps away");
    fm.msgController.addMsg("Next step: ${fm.nextSystemInPath(path)?.name}");
    fm.pilotController.action(fm.player,ActionType.planet,mod: 1.5);
  }

  void scout() {
    int depth = (fm.player.techLevel() / 16).ceil();
    fm.msgController.addMsg("Scouting nearby systems (depth: $depth)...");
    fm.explore(fm.player.system, depth);
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

  void shop() {
    Planet? planet = fm.player.planet; if (planet != null) { // && planet.commLvl.atOrAbove(DistrictLvl.medium)) {
      planet.shop ??= Shop.random(1,fm.rnd);
      if (fm.playerShip != null) {
        fm.menuController.showMenu(fm.menuController.createShopMenu(planet.shop!, fm.playerShip!),headerTxt: planet.shop!.name);
      }
    }
  }

  void newFooShamGame(ThrowList list) {
    Pilot? pilot = fm.playerShip?.pilot;
    if (pilot != null) {
      final fooShamGame = FooShamGame(ThrowList.rndList(fm.rnd),fm.rnd, difficulty: FooShamDifficulty.medium);
      fm.menuController.showMenu(fm.menuController.createThrowMenu(pilot, fooShamGame));
    }
  }

}