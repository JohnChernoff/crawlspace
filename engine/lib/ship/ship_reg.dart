import 'package:crawlspace_engine/actors/pilot.dart';
import 'package:crawlspace_engine/ship/ship.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/geometry/object.dart';

class ShipRegistry {
  Set<Ship> get all => _all;
  final Set<Ship> _all = {};
  final Map<Pilot, Ship> _byPilot = {};
  final Map<GridCell, Set<Ship>> _byCell = {};
  final Map<SpaceEnvironment, Set<Ship>> _hangars = {};

  void add(Ship ship) {
    _all.add(ship);
    if (ship.hasPilot) _byPilot[ship.pilot] = ship;
    _byCell.putIfAbsent(ship.loc.cell, () => {}).add(ship);
  }

  void remove(Ship ship) {
    _all.remove(ship);
    if (ship.hasPilot) _byPilot.remove(ship.pilot);
    _byCell[ship.loc.cell]?.remove(ship);
    for (final shp in _all.where((s) => s.targetShip == ship)) shp.targetShip = null;
  }

  //call before moving
  void reIndex(Ship ship, SpaceLocation newLoc) {
    _byCell[ship.loc.cell]?.remove(ship);
    _byCell.putIfAbsent(newLoc.cell, () => {}).add(ship);
  }

  void changePilot(Ship ship, Pilot newPilot) {
    if (ship.hasPilot) _byPilot.remove(ship.pilot);
    ship.pilot = newPilot;
    if (newPilot != nobody) _byPilot[newPilot] = ship;
  }

  void undock(Ship ship, SpaceEnvironment env) {
    _hangars[env]?.remove(ship);
    _byCell.putIfAbsent(ship.loc.cell, () => {}).add(ship);
    _all.add(ship);
  }

  void dock(Ship ship, SpaceEnvironment env) {
    _byCell[ship.loc.cell]?.remove(ship);
    _all.remove(ship);
    _hangars.putIfAbsent(env, () => {}).add(ship);
  }

  Set<Ship> hangar(SpaceEnvironment env) => _hangars[env] ?? {};
  Ship? byPilot(Pilot p) => _byPilot[p];
  Set<Ship> atCell(GridCell c) => Set.of(_byCell[c] ?? {});
  Set<Ship> atDomain(SpaceLocation loc) => _all.where((s) => s.loc.domain == loc.domain).toSet();
}
