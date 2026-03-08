import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import '../audio_service.dart';
import '../galaxy/geometry/coord_3d.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/hazards.dart';
import '../galaxy/geometry/impulse.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/geometry/path_gen.dart';
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
      if (sysLoc is SystemLocation) {
        if (sysLoc.cell.starClass != null) { //sysLoc.level.removeShip(ship);
          if (action) fm.pilotController.action(pilot,ActionType.sector);
          if (ship.loc.domain == Domain.system) { //didn't get pulled into impulse
            final stars = system.map.cells.values.where((c) => c is SectorCell && c.starClass != null);
            ship.move(SystemLocation(system,stars.first),fm.shipRegistry);
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
    if (playShip.loc is! SystemLocation) {
      fm.msgController.addMsg("Error: ship not at system level"); return;
    }
    glog("Creating impulse map...",level: DebugLevel.Fine); //Entering")
    int size = gridSize; //ship gridsize?
    ImpulseLevel impLevel;
    SpaceLocation sysLoc = playShip.loc;
    if (sysLoc is SystemLocation) { //final rnd = Random(l.cell.impulseSeed);
      if (sysLoc.level.impMapCache.containsKey(sysLoc.cell)) {
        impLevel = sysLoc.level.impMapCache[sysLoc.cell]!;
      }
      else {
        final sectorIon = sysLoc.cell.hazMap[Hazard.ion] ?? 0;
        final sectorNeb = sysLoc.cell.hazMap[Hazard.nebula] ?? 0;
        Map<Coord3D,ImpulseCell> cells = {};
        for (int x=0;x<size;x++) {
          for (int y=0;y<size;y++) {
            for (int z=0;z<size;z++) {
              final c = Coord3D(x, y, z);
              final cell = ImpulseCell(c,{
                Hazard.nebula : fm.mapRnd.nextDouble() < sectorNeb ? sectorNeb : 0,
                Hazard.ion : fm.mapRnd.nextDouble() < sectorIon ? sectorIon : 0,
                Hazard.roid : sysLoc.cell.hazMap[Hazard.roid] ?? 0,
                Hazard.wake: c.isEdge(size) ? 1 : 0
              });
              cells.putIfAbsent(c, () => cell);
            }
          }
        }
        final impMap = ImpulseMap(size,cells);
        if (sysLoc.cell.hasHaz(Hazard.roid)) PathGenerator.generate(impMap,4,0,fm.mapRnd, haz: Hazard.roid);
        impLevel = ImpulseLevel(impMap,sysLoc.cell);
        sysLoc.level.impMapCache.putIfAbsent(sysLoc.cell, () => impLevel);
        if (fm.galaxy.treasureMod.treasureMap.containsKey(sysLoc)) {
          for (final i in fm.galaxy.treasureMod.treasureMap[sysLoc]!) {
            impMap.rndCell(fm.itemRnd).items.add(i);
          }
        }
      }
      _enterImpulse(impLevel,playShip,cell: impLevel.map.cells.entries.firstWhere((c) => c.value.hazLevel == 0).value as ImpulseCell);
      fm.update();
      final ships = List.of(fm.shipRegistry.atCell(sysLoc.cell)); //avoids ConcurrentModificationError (hopefully)
      try {
        fm.msgController.addMsg("Entering impulse...");
        for (final ship in ships) {
          final h = ship.pilot.hostilityToward(fm.player.faction.species, fm.galaxy.civMod);
          fm.msgController.addMsg("${ship.name}${ship.pilot.hostile ? "(hostile)" : "(friendly)"} (${h.toStringAsFixed(2)}) is here");
          if (ship != playShip) _enterImpulse(impLevel,ship);
        }
      } on ConcurrentModificationError {
        glog("fark",error: true);
      }
    }
  }

  void _enterImpulse(ImpulseLevel impLvl, Ship? ship, {ImpulseCell? cell, safeDist = 4}) {
    if (ship == null) return;
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.impulse, activeOnly: false), ship, on: true, silent: true);
    fm.pilotController.toggleSystem(ship.systemControl.getEngine(Domain.system, activeOnly: false), ship, on: false, silent: true);
    final sysLoc = ship.loc;
    if (sysLoc is SystemLocation) {
      GridCell targetCell = cell ?? impLvl.map.rndCell(fm.mapRnd);
      final pic = playerImpulseLoc;
      if (pic != null) {
        bool okCell(GridCell cell) => targetCell.coord.distance(pic.cell.coord) >= safeDist && cell.hazLevel == 0;
        if (ship.npc && pic.systemLoc.cell == sysLoc.cell && !okCell(targetCell)) {
          List<GridCell> safeDistCells = [];
          while (safeDistCells.isEmpty && safeDist > 0) {
            safeDistCells = impLvl.map.cells.values.where((c) => okCell(c)).toList();
            safeDist--;
          };
          if (safeDistCells.isNotEmpty) {
            safeDistCells.shuffle(fm.mapRnd);
            targetCell = safeDistCells.first;
          }
        }
      }
      ship.move(ImpulseLocation(sysLoc, impLvl, targetCell),fm.shipRegistry);
      fm.audioController.newTrack(newMood: MusicalMood.danger);
    } //fm.pilotController.action(ship.pilot, ActionType.movement);
  }

  void enterSublight(Ship? ship) {
    if (ship == null) return;
    final impLoc = ship.loc;
    if (impLoc is ImpulseLocation) {
      final ships = fm.shipRegistry.inLevel(impLoc.level);
      if (ship == fm.playerShip && ships.length > 1 && ships.any((s) => s.pilot.hostile)) {
        if (ship.activeEffect(ShipEffect.folding)) {
          ships.forEach((s) => _exitImpulse(s, impLoc));
        } else {
          fm.msgController.addMsg("You cannot accelerate to system travel with hostile vessels in the area");
          return;
        }
      } else {
        _exitImpulse(ship, impLoc); //TODO: return all friendly ships to system travel as well?
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
    ship.move(impLoc.systemLoc, fm.shipRegistry);
  }

}