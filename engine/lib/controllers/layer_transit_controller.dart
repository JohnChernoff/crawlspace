import 'package:crawlspace_engine/path_gen2.dart';
import '../agent.dart';
import '../audio_service.dart';
import '../coord_3d.dart';
import '../grid.dart';
import '../hazards.dart';
import '../impulse.dart';
import '../location.dart';
import '../pilot.dart';
import '../ship.dart';
import '../system.dart';
import 'fugue_controller.dart';
import 'menu_controller.dart';
import 'pilot_controller.dart';

class LayerTransitController extends FugueController {
  Map<String,System> currentLinkMap = {};

  LayerTransitController(super.fm);

  ImpulseLocation? get playerImpulseLoc => pilotImpulseLoc(fm.player);
  ImpulseLocation? pilotImpulseLoc(Pilot p) {
    final l = fm.pilotMap[p]?.loc;
    if (l is ImpulseLocation) {
      return l;
    } else {
      return null;
    }
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
    final system = ship.loc.level; if (system is! System) {
      fm.msgController.addMsg("No system?!"); return;
    }

    List<ActionEntry> links = List.generate(system.links.length, (i) =>
        ActionEntry(fm.menuController.letter(i),
            system.links.elementAt(i).toString(),
                (m) => newSystem(fm.player, system.links.elementAt(i)),exitMenu: true)
    );
    fm.menuController.showMenu(links, headerTxt: "Hyperspace");
  }

  void hyperSpace(String letter) {
    if (currentLinkMap.containsKey(letter)) {
      fm.menuController.fm.menuController.exitInputMode();
      newSystem(fm.player, currentLinkMap[letter]!);
    }
  }

  void warp(Ship ship) {
    System system = fm.galaxy.getRandomLinkableSystem(
        fm.player.system, ignoreTraffic: true) ?? fm.galaxy.getRandomSystem(fm.player.system);
    if (newSystem(fm.player,system)) {
      //ship.warps.value--;
      fm.msgController.addMsg("*** EMERGENCY WARP ACTIVATED ***");
      if (ship.playship) {
        for (Agent agent in fm.agents) {
          agent.clueLvl = 25;
        }
      }
    }
    fm.pilotController.action(ship.pilot,ActionType.warp);
  }

  bool newSystem(Pilot pilot, System system) {
    if (fm.pilotMap.containsKey(pilot)) {
      Ship ship = fm.pilotMap[pilot]!;
      final sysLoc = ship.loc;
      if (sysLoc is SystemLocation) {
        if (sysLoc.cell.starClass != null) {
          sysLoc.level.removeShip(ship);
          final stars = system.map.cells.values.where((c) => c is SectorCell && c.starClass != null);
          ship.loc = SystemLocation(system, stars.first);
          pilot.system = system;
          fm.pilotController.action(pilot,ActionType.sector);
          return true;
        }
      }
      if (ship.playship) fm.scannerController.reset();
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
    fm.glog("Creating impulse map..."); //Entering")
    int size = gridSize; //ship gridsize?
    ImpulseLevel impLevel;
    ShipLocation sysLoc = playShip.loc;
    if (sysLoc is SystemLocation) { //final rnd = Random(l.cell.impulseSeed);
      if (sysLoc.level.impMapCache.containsKey(sysLoc.cell)) {
        impLevel = sysLoc.level.impMapCache[sysLoc.cell]!;
      }
      else {
        Map<Coord3D,ImpulseCell> cells = {};
        for (int x=0;x<size;x++) {
          for (int y=0;y<size;y++) {
            for (int z=0;z<size;z++) {
              final c = Coord3D(x, y, z);
              cells.putIfAbsent(c, () => ImpulseCell(c,{
                    Hazard.nebula : sysLoc.cell.hazMap[Hazard.nebula] ?? 0,
                    Hazard.ion : sysLoc.cell.hazMap[Hazard.ion] ?? 0,
                    Hazard.roid : sysLoc.cell.hazMap[Hazard.roid] ?? 0,
                    Hazard.wake: c.isEdge(size) ? 1 : 0
              }));
            }
          }
        }
        //impLevel = ImpulseLevel(ImpulseMap(size,cells),sysLoc.cell);
        final impMap = ImpulseMap(size,cells);
        if (sysLoc.cell.hazLevel > 0) PathGenerator2.generate(impMap,4,0,fm.rnd);
        impLevel = ImpulseLevel(impMap,sysLoc.cell);
        sysLoc.level.impMapCache.putIfAbsent(sysLoc.cell, () => impLevel);
      }
      _enterImpulse(impLevel,playShip,cell: impLevel.map.cells.entries.where((c) => c.value.hazLevel == 0).first.value as ImpulseCell);
      final ships = List.of(sysLoc.ships); //avoids ConcurrentModificationError (hopefully)
      try {
        fm.msgController.addMsg("Entering impulse...");
        for (final ship in ships) {
          fm.msgController.addMsg("${ship.name} is here");
          if (ship != playShip) _enterImpulse(impLevel,ship);
        }
      } on ConcurrentModificationError {
        fm.glog("fark");
      }
    }
  }

  void _enterImpulse(ImpulseLevel impLvl, Ship? ship, {ImpulseCell? cell, safeDist = 4}) {
    if (ship == null) return;
    final sysLoc = ship.loc;
    final pic = playerImpulseLoc;
    GridCell targetCell = cell ?? impLvl.map.rndCell(fm.rnd);
    if (sysLoc is SystemLocation && pic != null) {
      bool okCell(GridCell cell) => targetCell.coord.distance(pic.cell.coord) >= safeDist && cell.hazLevel == 0;
      if (ship.npc && pic.systemLoc.cell == sysLoc.cell && !okCell(targetCell)) {
        List<GridCell> safeDistCells = [];
        while (safeDistCells.isEmpty && safeDist > 0) {
          safeDistCells = impLvl.map.cells.values.where((c) => okCell(c)).toList();
          safeDist--;
        };
        if (safeDistCells.isNotEmpty) {
          safeDistCells.shuffle(fm.rnd);
          targetCell = safeDistCells.first;
        }
      }
    } //fm.pilotController.action(ship.pilot, ActionType.movement);
    ship.move(targetCell, impLevel: impLvl);
    fm.audioController.newTrack(newMood: MusicalMood.danger);
  }

  void enterSublight(Ship? ship) {
    if (ship == null) return;
    final impLoc = ship.loc;
    if (impLoc is ImpulseLocation) {
      if (ship == fm.playerShip) {
        impLoc.level.getAllShips().forEach((s) => _exitImpulse(s, impLoc));
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
    impLoc.level.removeShip(ship); //ship.loc = impLoc.systemLoc;
    ship.move(impLoc.systemLoc.cell, toSystem: true);
  }

}