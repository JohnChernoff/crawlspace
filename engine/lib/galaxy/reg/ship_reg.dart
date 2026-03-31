import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';

import '../../actors/pilot.dart';
import '../../ship/nav/nav.dart';
import '../../ship/ship.dart';
import '../geometry/grid.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';

class ShipRegistry {
  Set<Ship> get hangarShips => _all.where((s) => s.isDocked).toSet();
  Set<Ship> get activeShips => _all.where((s) => s.isFlying).toSet();
  Set<Ship> get all => _all;
  final Set<Ship> _all = {};
  final Map<Pilot, Ship> _byPilot = {};
  final Map<SpaceLocation, Set<Ship>> _byLoc = {};
  Ship? byPilot(Pilot p) => _byPilot[p];
  Set<Ship> atLocation(SpaceLocation loc) => Set.of(_byLoc[loc] ?? {}).whereType<Ship>().toSet();
  Set<Ship> atCell(GridCell c) => atLocation(c.loc);
  Set<Ship> interactable(SpaceLocation loc) => _all.where((s) => loc.interactable(s.loc)).toSet();
  Set<Ship> atDomain(SpaceLocation loc) => atLocation(loc).where((s) => s.loc.domain == loc.domain).toSet();
  Set<Ship> atHangarLocation(SpaceEnvironment env) => _all.where((s) => s.hangarOrNull == env).toSet();

  PilotRegistry pilots;
  ShipRegistry(this.pilots);

  void _add(Ship ship, SpaceLocation loc) {
    _all.add(ship);
    _byLoc.putIfAbsent(loc, () => {}).add(ship);
    ship.setRegLoc(loc);
  }

  void addFlying(Ship ship, SpaceLocation loc, Pilot pilot) {
    _add(ship,loc);
    ship.state = FlightState(pilot, ShipNav(ship));
    _byPilot[ship.pilot] = ship;
    pilots.add(ship.pilot);
  }

  void addDocked(Ship ship, SpaceEnvironment env) {
    _add(ship,env.loc);
    ship.state = DockedState(env);
  }

  void _remove(Ship ship) {
    _all.remove(ship);
    _byLoc[ship.maybeLoc]?.remove(ship);
  }

  void remove(Ship ship) {
    _remove(ship);
    if (ship.isFlying) {
      _byPilot.remove(ship.pilot);
    }
    for (final shp in activeShips.where((s) => s.nav.targetShip == ship)) {
      shp.nav.targetShip = null;
    }
  }

  void move(Ship ship, SpaceLocation newLoc) {
    _remove(ship);
    _add(ship, newLoc);
  }

  void changePilot(Ship ship, Pilot newPilot) {
    _byPilot.remove(ship.pilot);
    final state = ship.state;
    if (state is FlightState) state.pilot = newPilot;
    _byPilot[newPilot] = ship;
  }

  void undock(Ship ship, Pilot pilot) {
    if (ship.isDocked) {
      ship.state = FlightState(pilot, ShipNav(ship));
      pilot.locale = AboardShip(ship);
    }
  }

  void dock(Ship ship, SpaceEnvironment env) {
    if (ship.isFlying) {
      ship.pilot.locale = AtEnvironment(env);
      ship.state = DockedState(env);
    }
  }
}


