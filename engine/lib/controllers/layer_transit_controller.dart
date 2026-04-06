import 'package:crawlspace_engine/controllers/xeno_controller.dart';
import 'package:crawlspace_engine/fugue_engine.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../actors/pilot.dart';
import '../galaxy/geometry/sector.dart';
import '../ship/ship.dart';
import '../galaxy/system.dart';
import 'fugue_controller.dart';
import 'pilot_controller.dart';

enum DomainDir { up, down }

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
      fm.msg("No ship!"); return;
    }
    final cell = ship.loc.cell; if (cell is! SectorCell) {
      fm.msg("Wrong layer!"); return;
    }
    final stars = fm.galaxy.stars.inSector(cell.loc); if (stars.isEmpty) {
      fm.msg("No star!"); return;
    }
    fm.menuController.showMenu(() => fm.menuFactory.buildHyperspaceMenu(ship.loc.system), headerTxt: "Hyperspace");
  }

  void emergencyWarp(Ship ship) {
    System system = fm.galaxy.getRandomLinkableSystem(
        fm.player.system, ignoreTraffic: true) ?? fm.galaxy.getRandomSystem(excludeSystems: [fm.player.system]);
    if (newSystem(fm.player,system)) {
      //ship.warps.value--;
      fm.msg("*** EMERGENCY WARP ACTIVATED ***");
    }
    fm.pilotController.action(ship.pilot,ActionType.warp);
  }

  bool newSystem(Pilot pilot, System system, {action = true}) {
    Ship? ship = fm.getShip(pilot); if (ship != null) {
      final sysLoc = ship.loc;
      if (sysLoc is SectorLocation) {
        if (fm.galaxy.stars.findGate(sysLoc.system).sector == sysLoc) { //sysLoc.level.removeShip(ship);
          if (action) fm.pilotController.action(pilot,ActionType.sector);
          if (ship.loc.domain == Domain.system) { //didn't get pulled into impulse
            ship.move(SectorLocation(system,fm.galaxy.stars.findGate(system).sectorCoord),fm);
            system.visit(fm);
            if (ship.itinerary != null) {
              if (ship.itinerary!.last == system) {
                ship.itinerary = null;
                if (ship.playship) fm.msg("You have arrived at your destination");
              }
              else ship.itinerary = fm.galaxy.topo.graph.shortestPath(system, ship.itinerary!.last);
            }
            fm.update();
            if (ship.playship) {
              fm.msg("New System: ${system.name}");
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

  void changeDomain(Ship ship, DomainDir dir) {
    final shipLoc = ship.loc;
    final indexDir = dir == DomainDir.up ? -1 : 1;
    int domIndex = (shipLoc.domain.index + indexDir).clamp(Domain.hyperspace.index, Domain.orbital.index);
    Domain newDomain = Domain.values.elementAt(domIndex);
    if (newDomain == Domain.hyperspace) selectHyperSpaceLink();
    if (dir == DomainDir.up) {
      if (hostileCheck(ship) && !ship.activeEffect(ShipEffect.folding)) {
        if (ship.playship) fm.msg("You cannot accelerate to $newDomain travel with hostile vessels in the area");
      }
      else if (shipLoc.upper != null) { //null shouldn't occur here, but hey
        if (ship.playship) fm.msg("Exiting ${shipLoc.domain}, resuming $newDomain travel");
        ship.move(shipLoc.upper!, fm);
      } //down
    } else if (shipLoc.domain == Domain.orbital) {
      if (ship.playship) fm.msg("You cannot do that!");
    } else if (shipLoc is SectorLocation && !shipLoc.cell.hasGravitySource(fm.galaxy)) {
        if (ship.playship) fm.msg("You cannot descend to impulse travel in deep space without a local grav buoy, planet or star.");
    } else if (ship.canLand(fm.galaxy)) {
        fm.planetsideController.planetFall();
    } else if (shipLoc.domain == Domain.impulse) {
      if (ship.playship) fm.msg(shipLoc.cell.planets(fm.galaxy).isNotEmpty ? "Cannot land: overspeed" : "No planet");
    } else {
      final map = shipLoc.cell.map;
      final destCell = (ship.npc)
          ? selectNpcCell(ship)
          : map.values.firstWhere((c) => c.hazLevel == 0);
      final newLoc = destCell.loc;
      if (ship.playship) {
        newLoc.grid.updateGravMap(fm.galaxy);
        ship.move(newLoc,fm);
        final proxShips = List.of(fm.galaxy.ships.atLocation(shipLoc)); //avoids ConcurrentModificationError (hopefully)
        try {
          fm.msg("Entering $newDomain...");
          for (final ps in proxShips) {
            final h = ps.pilot.hostilityToward(fm.player.faction.species, fm.galaxy.civMod);
            fm.msg("${ps.name}${ps.pilot.hostile ? "(hostile)" : "(friendly)"} (${h.toStringAsFixed(2)}) is here");
            if (ps.npc) changeDomain(ps, DomainDir.down);
          }
        } on ConcurrentModificationError {
          glog("fark",error: true);
        }
      } else if (fm.playerShip?.loc == ship.loc) {
        fm.msg("Interdiction!");
        changeDomain(fm.playerShip!,DomainDir.down);
        return;
      } else {
        ship.move(newLoc,fm);
      }
    }
    fm.update();
  }

  GridCell selectNpcCell(Ship ship, {safeDist = 4}) {
    final map = ship.loc.cell.map;
    var targetCell = map.rndCell(fm.mapRnd);
    final pLoc = fm.playerShip?.loc;
    if (pLoc != null) {
      bool okCell(GridCell c) =>
          c.loc.dist(pLoc) >= safeDist && c.hazLevel == 0;
      if (!okCell(targetCell)) {
        List<GridCell> safeDistCells = [];
        while (safeDistCells.isEmpty && safeDist > 0) {
          safeDistCells = map.values.where((c) => okCell(c)).toList();
          safeDist--;
        };
        if (safeDistCells.isNotEmpty) {
          safeDistCells.shuffle(fm.mapRnd);
          targetCell = safeDistCells.first;
        }
      }
    }
    return targetCell;
  }

  bool hostileCheck(Ship ship) {
    final ships = fm.galaxy.ships.atDomain(ship.loc);
    return (ship == fm.playerShip && ships.length > 1 && ships.any((s) => s.pilot.hostile));
  }

}
