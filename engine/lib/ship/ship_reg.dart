import 'package:crawlspace_engine/ship/ship.dart';
import '../actors/pilot.dart';
import '../galaxy/geometry/grid.dart';
import '../galaxy/geometry/location.dart';
import '../galaxy/geometry/object.dart';

class ShipRegistry {
  Set<Ship> get all => _all;
  final Set<Ship> _all = {};
  final Map<Pilot, Ship> _byPilot = {};
  final Map<SpaceLocation, Set<Ship>> _byLoc = {};
  final Map<SpaceEnvironment, Set<Ship>> _hangars = {};

  void add(Ship ship) {
    _all.add(ship);
    if (ship.hasPilot) _byPilot[ship.pilot] = ship;
    _byLoc.putIfAbsent(ship.loc, () => {}).add(ship);
  }

  void remove(Ship ship) {
    _all.remove(ship);
    if (ship.hasPilot) _byPilot.remove(ship.pilot);
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    for (final shp in _all.where((s) => s.targetShip == ship)) {
      shp.targetShip = null;
    }
  }

  // call before moving
  void reIndex(Ship ship, SpaceLocation newLoc) {
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    _byLoc.putIfAbsent(newLoc, () => {}).add(ship);
  }

  void changePilot(Ship ship, Pilot newPilot) {
    if (ship.hasPilot) _byPilot.remove(ship.pilot);
    ship.pilot = newPilot;
    if (newPilot != nobody) _byPilot[newPilot] = ship;
  }

  void undock(Ship ship, SpaceEnvironment env) {
    _hangars[env]?.remove(ship);
    _byLoc.putIfAbsent(ship.loc, () => {}).add(ship);
    _all.add(ship);
  }

  void dock(Ship ship, SpaceEnvironment env) {
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    _all.remove(ship);
    _hangars.putIfAbsent(env, () => {}).add(ship);
  }

  Set<Ship> hangar(SpaceEnvironment env) => _hangars[env] ?? {};
  Ship? byPilot(Pilot p) => _byPilot[p];
  Set<Ship> atLocation(SpaceLocation loc) => Set.of(_byLoc[loc] ?? {});
  Set<Ship> atCell(GridCell c) => atLocation(c.loc);
  Set<Ship> atDomain(SpaceLocation loc) =>
      _all.where((s) => s.loc.domain == loc.domain).toSet();
}
