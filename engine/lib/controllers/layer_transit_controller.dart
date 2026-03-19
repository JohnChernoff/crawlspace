import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import '../audio_service.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/impulse.dart';
import '../galaxy/geometry/location.dart';
import '../actors/pilot.dart';
import '../galaxy/geometry/sector.dart';
import '../ship/ship.dart';
import '../galaxy/system.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

class LayerTransitController extends FugueController {
  Map<String,System> currentLinkMap = {};

  LayerTransitController(super.fm);

  ImpulseLocation? get playerImpulseLoc => pilotImpulseLoc(fm.player);
  ImpulseLocation? pilotImpulseLoc(Pilot p) {
    final l = fm.getShip(p)?.loc;
    if (l is ImpulseLocation) return l; else return null;
  }

  void selectHyperSpaceLink() {
    Ship? ship = fm.playerShip; if (ship == null) {
      fm.msgController.addMsg("No ship!"); return;
    }
    final cell = ship.loc.cell; if (cell is! SectorCell) {
      fm.msgController.addMsg("Wrong layer!"); return;
    }
    final star = cell.starClass; if (star == null) {
      fm.msgController.addMsg("No star!"); return;
    }
    fm.menuController.showMenu(() => fm.menuFactory.buildHyperspaceMenu(ship.loc.system), headerTxt: "Hyperspace");
  }

  void emergencyWarp(Ship ship) {
    System system = fm.galaxy.getRandomLinkableSystem(
        fm.player.system, ignoreTraffic: true) ?? fm.galaxy.getRandomSystem(excludeSystems: [fm.player.system]);
    if (newSystem(fm.player,system)) {
      //ship.warps.value--;
      fm.msgController.addMsg("*** EMERGENCY WARP ACTIVATED ***");
    }
    fm.pilotController.action(ship.pilot,ActionType.warp);
  }

  bool newSystem(Pilot pilot, System system, {action = true}) {
    Ship? ship = fm.getShip(pilot); if (ship != null) {
      final sysLoc = ship.loc;
      if (sysLoc is SectorLocation) {
        if (sysLoc.cell.starClass != null) { //sysLoc.level.removeShip(ship);
          if (action) fm.pilotController.action(pilot,ActionType.sector);
          if (ship.loc.domain == Domain.system) { //didn't get pulled into impulse
            final stars = system.map.values.where((c) => c.starClass != null);
            ship.move(SectorLocation(system,stars.first.coord),fm.galaxy.ships);
            system.visit(fm);
            if (ship.itinerary != null) {
              if (ship.itinerary!.last == system) {
                ship.itinerary = null;
                if (ship.playship) fm.msgController.addMsg("You have arrived at your destination");
              }
              else ship.itinerary = fm.galaxy.topo.graph.shortestPath(system, ship.itinerary!.last);
            }
            fm.update();
            if (ship.playship) {
              fm.msgController.addMsg("New System: ${system.name}");
              fm.scannerController.reset();
            }
            ship.scanSystem(system,fm);
            return true;
          }
        }
      }
    }
    return false;
  }

  void createAndEnterImpulse({int gridSize = 8, int minDist = 4}) {
    Ship? playShip = fm.playerShip;
    if (playShip == null) {
      fm.msgController.addMsg("You're not in a ship."); return;
    }
    if (playShip.loc is! SectorLocation) {
      fm.msgController.addMsg("Error: ship not at system level"); return;
    }
    glog("Creating impulse map...",level: DebugLevel.Fine); //Entering")
    SpaceLocation sysLoc = playShip.loc;
    if (sysLoc is SectorLocation) { //final rnd = Random(l.cell.impulseSeed);
      final impMap = sysLoc.cell.map;
      _enterImpulse(impMap,playShip,cell: impMap.values.firstWhere((c) => c.hazLevel == 0));
      fm.update();
      final ships = List.of(fm.galaxy.ships.atCell(sysLoc.cell)); //avoids ConcurrentModificationError (hopefully)
      try {
        fm.msgController.addMsg("Entering impulse...");
        for (final ship in ships) {
          final h = ship.pilot.hostilityToward(fm.player.faction.species, fm.galaxy.civMod);
          fm.msgController.addMsg("${ship.name}${ship.pilot.hostile ? "(hostile)" : "(friendly)"} (${h.toStringAsFixed(2)}) is here");
          if (ship != playShip) _enterImpulse(impMap,ship);
        }
      } on ConcurrentModificationError {
        glog("fark",error: true);
      }
    }
  }

  void _enterImpulse(SectorMap sectorMap, Ship? ship, {ImpulseCell? cell, safeDist = 4}) {
    if (ship == null) return;
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.impulse, activeOnly: false), ship, on: true, silent: true);
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.system, activeOnly: false), ship, on: false, silent: true);
    final sysLoc = ship.loc;
    if (sysLoc is SectorLocation) {
      ImpulseCell targetCell = cell ?? sectorMap.rndCell(fm.mapRnd);
      final pic = playerImpulseLoc;
      if (pic != null) {
        //bool okCell(GridCell cell) => targetCell.dist(pic) >= safeDist && cell.hazLevel == 0;
        bool okCell(ImpulseCell c) => c.loc.dist(pic) >= safeDist && c.hazLevel == 0;
        if (ship.npc && pic.sectorCoord == sysLoc.cell.coord && !okCell(targetCell)) {
          List<ImpulseCell> safeDistCells = [];
          while (safeDistCells.isEmpty && safeDist > 0) {
            safeDistCells = sectorMap.values.where((c) => okCell(c)).toList();
            safeDist--;
          };
          if (safeDistCells.isNotEmpty) {
            safeDistCells.shuffle(fm.mapRnd);
            targetCell = safeDistCells.first;
          }
        }
      }
      ship.move(ImpulseLocation(ship.loc.system,sysLoc.cell.coord,targetCell.coord),fm.galaxy.ships);
      ship.nav.resetMotionState();
      fm.audioController.newTrack(newMood: MusicalMood.danger);
    } //fm.pilotController.action(ship.pilot, ActionType.movement);
  }

  void enterSublight(Ship? ship) {
    if (ship == null) return;
    final impLoc = ship.loc;
    if (impLoc is ImpulseLocation) {
      final ships = fm.galaxy.ships.atDomain(impLoc);
      if (ship == fm.playerShip && ships.length > 1 && ships.any((s) => s.pilot.hostile)) {
        if (ship.activeEffect(ShipEffect.folding)) {
          ships.forEach((s) => _exitImpulse(s, impLoc));
        } else {
          fm.msgController.addMsg("You cannot accelerate to system travel with hostile vessels in the area");
          return;
        }
      } else {
        _exitImpulse(ship, impLoc);
      }
      fm.audioController.newTrack(newMood: MusicalMood.space);
      fm.pilotController.action(ship.pilot, ActionType.movement);
    } else {
      fm.msgController.addMsg("Error: ship not at impulse level");
    }
  }

  void _exitImpulse(Ship ship, ImpulseLocation impLoc) {
    fm.msgController.addMsg("Exiting impulse, resuming system travel");
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.system, activeOnly: false), ship, on: true, silent: true);
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.impulse, activeOnly: false), ship, on: false, silent: true);
    ship.move(impLoc.sector, fm.galaxy.ships);
    ship.nav.resetMotionState();
  }

}