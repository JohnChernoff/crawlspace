
import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';

import '../../actors/pilot.dart';
import '../../ship/hangar_ship.dart';
import '../../ship/ship.dart';
import '../geometry/grid.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';

class ShipRegistry {
  Set<HangarShip> get hangarShips => _all.whereType<HangarShip>().toSet();
  Set<Ship> get activeShips => _all.whereType<Ship>().toSet();
  Set<HangarShip> get all => _all;
  final Set<HangarShip> _all = {};
  final Map<Pilot, Ship> _byPilot = {};
  final Map<SpaceLocation, Set<HangarShip>> _byLoc = {};
  Ship? byPilot(Pilot p) => _byPilot[p];
  Set<Ship> atLocation(SpaceLocation loc) => Set.of(_byLoc[loc] ?? {}).whereType<Ship>().toSet();
  Set<Ship> atCell(GridCell c) => atLocation(c.loc);
  Set<Ship> atDomain(SpaceLocation loc) => atLocation(loc).where((s) => s.loc.domain == loc.domain).toSet();
  Set<HangarShip> atHangarLocation(SpaceLocation loc) => Set.of(_byLoc[loc] ?? {}).whereType<HangarShip>().toSet();

  PilotRegistry pilots;
  ShipRegistry(this.pilots);

  void add(HangarShip ship) {
    _all.add(ship);
    _byLoc.putIfAbsent(ship.loc, () => {}).add(ship);
    if (ship is Ship) {
      _byPilot[ship.pilot] = ship;
      pilots.add(ship.pilot);
    }
  }

  void remove(HangarShip ship) {
    _all.remove(ship);
    if (ship is Ship) {
      _byPilot.remove(ship.pilot);
    }
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    for (final shp in activeShips.where((s) => s.nav.targetShip == ship)) {
      shp.nav.targetShip = null;
    }
  }

  // call before moving
  void move(Ship ship, SpaceLocation newLoc) {
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    _byLoc.putIfAbsent(newLoc, () => {}).add(ship);
    ship.loc = newLoc;
    //if (ship.nav.heading == null) ship.nav.pos = Position.fromCoord(ship.loc.cell.coord);
  }

  void changePilot(Ship ship, Pilot newPilot) {
    _byPilot.remove(ship.pilot);
    ship.pilot = newPilot;
    _byPilot[newPilot] = ship;
  }

  void undock(HangarShip ship, Pilot pilot) {
    remove(ship);
    final undockedShip = Ship.board(pilot, ship);
    add(undockedShip);
    undockedShip.undock(ship);
    pilot.locale = AboardShip(undockedShip);
  }

  void dock(Ship ship, SpaceEnvironment env) {
    ship.pilot.locale = AtEnvironment(env);
    remove(ship);
    final dockedShip = HangarShip.toHangar(ship);
    add(dockedShip);
    dockedShip.systemControl = ship.systemControl;
    dockedShip.systemControl.ship = dockedShip; // fix back-reference
    dockedShip.inventory = ship.inventory;
  }
}
