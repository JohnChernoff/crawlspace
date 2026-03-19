import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import '../../actors/pilot.dart';
import '../../actors/player.dart';
import '../../item.dart';
import '../../ship/ship.dart';
import '../geometry/grid.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';
import '../planet.dart';
import '../system.dart';

class RegModel extends GalaxySubMod {
  late ItemRegistry items = ItemRegistry(this.galaxy);
  PlanetRegistry planets = PlanetRegistry();
  PilotRegistry pilots = PilotRegistry();
  late ShipRegistry ships = ShipRegistry(pilots);
  RegModel(super.galaxy);
}

typedef ItemMap = Map<SpaceLocation,Set<Item>>;
typedef ItemEntry = MapEntry<SpaceLocation, Set<Item>>;
typedef ItemSet = Set<ItemEntry>;

class PlanetRegistry {
  // Ground truth — planet's actual position
  final Map<Planet, ImpulseLocation> _locations = {};

  // Derived fast-lookup indexes
  final Map<System, Set<Planet>> _bySystem = {};
  final Map<SectorLocation, Set<Planet>> _bySector = {};
  final Map<ImpulseLocation,Planet> _byImpulse = {};

  void register(Planet p, ImpulseLocation loc) {
    _locations[p] = loc;
    _bySystem.putIfAbsent(loc.system, () => {}).add(p);
    _bySector.putIfAbsent(
        SectorLocation(loc.system, loc.sectorCoord), () => {}
    ).add(p);
    assert(!_byImpulse.containsKey(loc),
    'Planet ${_byImpulse[loc]?.name} already at $loc');
    _byImpulse[loc] = p;
    loc.cell.clearHazards();
  }

  void move(Planet p, ImpulseLocation newLoc) {
    final old = _locations[p];
    if (old != null) {
      _bySystem[old.system]?.remove(p);
      _bySector[SectorLocation(old.system, old.sectorCoord)]?.remove(p);
      _byImpulse.remove(old);
    }
    register(p, newLoc);
  }

  ImpulseLocation? locationOf(Planet p) => _locations[p];
  Set<Planet> inSystem(System s) => _bySystem[s] ?? {};
  Set<Planet> inSector(SectorLocation s) => _bySector[s] ?? {};
  Planet? byImpulse(ImpulseLocation loc) => _byImpulse[loc];

  ImpulseLocation randomUnoccupiedLocationBySector(System system, SectorLocation sector, Random rnd) {
    late ImpulseLocation loc;
    do {
      loc = ImpulseLocation(system,
          sector.sectorCoord, Coord3D.random(system.impulseMapDim, rnd));
    } while (byImpulse(loc) != null);
    return loc;
  }

  ImpulseLocation randomUnoccupiedLocation(System system, Random rnd) {
    late ImpulseLocation loc;
    do {
      loc = ImpulseLocation(system,
          Coord3D.random(system.systemMapDim, rnd), Coord3D.random(system.impulseMapDim, rnd));
    } while (byImpulse(loc) != null);
    return loc;
  }
}

class ItemRegistry {
  Galaxy galaxy;
  ItemMap _repository = {};
  final Map<Item, SpaceLocation> _itemIndex = {};

  ItemRegistry(this.galaxy);

  void addItem(Item item, SpaceLocation loc) {
    _repository.putIfAbsent(loc, () => {}).add(item);
    _itemIndex[item] = loc;
  }

  void removeItem(Item item) {
    final loc = _itemIndex.remove(item);
    if (loc != null) _repository[loc]?.remove(item);
  }

  SpaceLocation? locationOf(Item item) => _itemIndex[item];

  MapEntry<SpaceLocation,Item> nearestItem(System sys) {
    final loc = _repository.keys
        .sorted((a,b) => galaxy.topo.distance(a.system, sys)
        .compareTo(galaxy.topo.distance(b.system, sys))).first;
    return MapEntry(loc, _repository[loc]!.first);
  }

  ItemSet inSystem(System sys) => _repository.entries.where((m) => m.key.system == sys).toSet();
  Set<Item>? atLocation(SpaceLocation loc) => _repository[loc];
//Set<Item> atCell(GridCell cell) => _repository.entries.where((m) => m.key.cell == cell).expand((e) => e.value).toSet();
}

class ShipRegistry {
  Set<Ship> get all => _all;
  final Set<Ship> _all = {};
  final Map<Pilot, Ship> _byPilot = {};
  final Map<SpaceLocation, Set<Ship>> _byLoc = {};
  final Map<SpaceEnvironment, Set<Ship>> _hangars = {};

  Set<Ship> hangar(SpaceEnvironment env) => _hangars[env] ?? {};
  Ship? byPilot(Pilot p) => _byPilot[p];
  Set<Ship> atLocation(SpaceLocation loc) => Set.of(_byLoc[loc] ?? {});
  Set<Ship> atCell(GridCell c) => atLocation(c.loc);
  Set<Ship> atDomain(SpaceLocation loc) =>
      _all.where((s) => s.loc.domain == loc.domain).toSet();

  PilotRegistry pilots;
  ShipRegistry(this.pilots);

  void add(Ship ship) {
    _all.add(ship);
    if (ship.hasPilot) _byPilot[ship.pilot] = ship; //TODO: get rid of nobody
    _byLoc.putIfAbsent(ship.loc, () => {}).add(ship);
    pilots.add(ship.pilot);
  }

  void remove(Ship ship) {
    _all.remove(ship);
    if (ship.hasPilot) _byPilot.remove(ship.pilot);
    _byLoc[ship.loc]?.remove(ship);
    if (_byLoc[ship.loc]?.isEmpty ?? false) {
      _byLoc.remove(ship.loc);
    }
    for (final shp in _all.where((s) => s.nav.targetShip == ship)) {
      shp.nav.targetShip = null;
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
}

class PilotRegistry {
  final Set<Pilot> _all = {};

  void add(Pilot p) => _all.add(p);
  void remove(Pilot p) => _all.remove(p);

  Iterable<Pilot> get all => _all.where((p) => p != nobody);
  Iterable<Pilot> get npcs => _all.where((p) => p is! Player);
  Iterable<Pilot> withShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) != null);
  Iterable<Pilot> withoutShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) == null);
}



