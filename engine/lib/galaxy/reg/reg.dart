import 'package:crawlspace_engine/galaxy/galaxy.dart';
import 'package:crawlspace_engine/galaxy/geometry/object.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import '../../actors/pilot.dart';
import '../../actors/player.dart';
import '../../item.dart';
import '../../ship/hangar_ship.dart';
import '../../ship/nav.dart';
import '../../ship/ship.dart';
import '../geometry/grid.dart';
import '../geometry/location.dart';
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
  Set<Item>? atLocationOrNull(SpaceLocation loc) => _repository[loc];
  Set<Item> atLocation(SpaceLocation loc) => _repository[loc] ?? {};
  bool anyAt(SpaceLocation loc) => atLocation(loc).isNotEmpty;
//Set<Item> atCell(GridCell cell) => _repository.entries.where((m) => m.key.cell == cell).expand((e) => e.value).toSet();
}

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
    if (ship.nav.heading == null) ship.nav.pos = Position.fromCoord(ship.loc.cell.coord);
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
    undockedShip.systemControl = ship.systemControl;
    undockedShip.systemControl.ship = undockedShip; // fix back-reference
    undockedShip.inventory = ship.inventory;
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

class PilotRegistry {
  final Set<Pilot> _all = {};

  void add(Pilot p) => _all.add(p);
  void remove(Pilot p) => _all.remove(p);

  Iterable<Pilot> get all => _all;
  Iterable<Pilot> get npcs => _all.where((p) => p is! Player);
  Iterable<Pilot> withShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) != null);
  Iterable<Pilot> withoutShips(ShipRegistry ships, {npc = true}) =>
      (npc ? npcs : all).where((p) => ships.byPilot(p) == null);
}



