import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/plan_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/star_reg.dart';
import 'package:crawlspace_engine/ship/nav.dart';
import '../../actors/pilot.dart';
import '../../item.dart';
import '../../ship/hangar_ship.dart';
import '../../ship/ship.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';
import '../system.dart';
import 'item_reg.dart';

class RegModel extends GalaxySubMod {
  late ItemRegistry items = ItemRegistry(this.galaxy);
  PlanetRegistry planets = PlanetRegistry();
  PilotRegistry pilots = PilotRegistry();
  late ShipRegistry ships = ShipRegistry(pilots);
  StarRegistry stars = StarRegistry();
  RegModel(super.galaxy);
}

typedef ItemMap = Map<SpaceLocation,Set<Item>>;
typedef ItemEntry = MapEntry<SpaceLocation, Set<Item>>;
typedef ItemSet = Set<ItemEntry>;

abstract class ImpulseRegistry<T extends Locatable<ImpulseLocation>>
    extends _SectorIndexedRegistry<T, ImpulseLocation> {
  final Map<ImpulseLocation, T> _byImpulse = {};

  T? byImpulse(ImpulseLocation loc) => _byImpulse[loc];

  @override
  void register(T obj, ImpulseLocation loc) {
    assert(!_byImpulse.containsKey(loc),
    '$T ${_byImpulse[loc]} already at $loc');
    super.register(obj, loc);
    _byImpulse[loc] = obj;
  }

  @override
  ImpulseLocation remove(T obj, {moving = false}) {
    final old = super.remove(obj, moving: moving);
    if (!identical(_byImpulse[old], obj)) {
      throw StateError('Unexpected registry state for $obj at $old');
    }
    _byImpulse.remove(old);
    return old;
  }

  Coord3D randomEmptyCoord(System system, Coord3D sectorCoord, GridDim dim, Random rnd) {
    var c;
    do {
      c = dim.rndCoord(rnd);
    }
    while (byImpulse(ImpulseLocation(system, sectorCoord, c)) != null);
    return c;
  }
}

abstract class SectorRegistry<T extends Locatable<SectorLocation>>
    extends _SectorIndexedRegistry<T, SectorLocation> {
}

abstract class _SectorIndexedRegistry<T extends Locatable<L>, L extends SectorLocatable> extends SpaceRegistry<T, L> {
  final Map<SectorLocation, Set<T>> _bySector = {};
  Set<T> inSector(SectorLocation s) => _bySector[s] ?? {};

  @override
  void register(T obj, L loc) {
    super.register(obj, loc);
    _bySector.putIfAbsent(
      SectorLocation(loc.system, loc.sectorCoord),
          () => {},
    ).add(obj);
  }

  @override
  L remove(T obj, {moving = false}) {
    final old = super.remove(obj, moving: moving);
    _bySector[SectorLocation(old.system, old.sectorCoord)]?.remove(obj);
    return old;
  }
}

abstract class SpaceRegistry<T extends Locatable<L>, L extends SpaceLocation> {
  final Map<T, L> _locations = {};
  final Map<System, Set<T>> _bySystem = {};

  void register(T obj, L loc) {
    assert(!_locations.containsKey(obj), '$obj is already registered at ${_locations[obj]}',);
    obj._onRegistered(loc);
    _locations[obj] = loc;
    _bySystem.putIfAbsent(loc.system, () => {}).add(obj);
    onRegister(obj, loc);
  }

  void move(T obj, L newLoc) {
    remove(obj, moving: true);
    register(obj, newLoc);
  }

  L remove(T obj, {moving = false}) {
    final old = _locations[obj];
    if (old == null) {
      throw StateError('$obj is not registered');
    }

    _locations.remove(obj);
    _bySystem[old.system]?.remove(obj);

    if (!moving) obj._onRemoved();
    onRemove(obj, old);
    return old;
  }

  L? locationOf(T obj) => _locations[obj];
  Set<T> inSystem(System s) => _bySystem[s] ?? {};

  void onRegister(T obj, L loc) {}
  void onRemove(T obj, L loc) {}
}

abstract class ContainableRegistry<T extends Containable<ImpulseLocation>>
    extends ImpulseRegistry<T> {
  void contain(T obj, Locatable<ImpulseLocation> container) {
    remove(obj);
    obj.setContainer(container);
  }

  void place(T obj, ImpulseLocation loc) {
    obj.setContainer(null);
    register(obj, loc);
  }
}

abstract class Locatable<T extends SpaceLocation> {
  T? _loc;
  T get loc => _locOrThrow();
  T? get maybeLoc => _loc;
  bool get isRegistered => _loc != null;

  T _locOrThrow() {
    final l = maybeLoc;
    if (l == null) {
      throw StateError('$runtimeType has no registered location');
    }
    return l;
  }

  void _onRegistered(T loc) {
    _loc = loc;
  }

  void _onRemoved() {
    _loc = null;
  }
}

abstract class Containable<T extends SpaceLocation> extends Locatable<T> {
  Locatable<T>? _container;
  Locatable<T>? get container => _container;

  bool get hasDirectLocation => _loc != null;
  bool get hasLocation => maybeLoc != null;

  @override
  T? get maybeLoc => _loc ?? container?.maybeLoc;

  @override
  void _onRegistered(T loc) {
    _container = null;
    super._onRegistered(loc);
  }

  void setContainer(Locatable<T>? value) {
    if (identical(value, this)) {
      throw StateError('$runtimeType cannot contain itself');
    }

    Locatable<T>? cur = value;
    final seen = <Locatable<T>>{};

    while (cur != null) {
      if (!seen.add(cur)) {
        throw StateError('Cycle detected in containment chain');
      }
      if (identical(cur, this)) {
        throw StateError('$runtimeType cannot be contained by its descendant');
      }
      cur = cur is Containable<T> ? cur.container : null;
    }

    _container = value;
    _loc = null;
  }
}

//in this file because HangarShip extends Locatable
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

  void add(HangarShip ship, SpaceLocation loc, {init = false}) {
    _all.add(ship);
    _byLoc.putIfAbsent(loc, () => {}).add(ship);
    ship._loc = loc;
    if (ship is Ship) {
      _byPilot[ship.pilot] = ship;
      pilots.add(ship.pilot);
      if (init) ship.nav = ShipNav(ship); //nav requires a loc for initialization
    }
  }

  void remove(HangarShip ship, {moving = false}) {
    _all.remove(ship);
    if (ship is Ship && !moving) {
      _byPilot.remove(ship.pilot);
    }
    _byLoc[ship.maybeLoc]?.remove(ship);
    //if (_byLoc[ship.maybeLoc]?.isEmpty ?? false) { _byLoc.remove(ship.loc); }
    if (!moving) {
      for (final shp in activeShips.where((s) => s.nav.targetShip == ship)) {
        shp.nav.targetShip = null;
      }
    }
  }

  // call before moving
  void move(Ship ship, SpaceLocation newLoc) {
    remove(ship, moving: true);
    add(ship, newLoc);
  }

  void changePilot(Ship ship, Pilot newPilot) {
    _byPilot.remove(ship.pilot);
    ship.pilot = newPilot;
    _byPilot[newPilot] = ship;
  }

  void undock(HangarShip ship, Pilot pilot) {
    remove(ship);
    final undockedShip = Ship.board(pilot, ship);
    add(undockedShip,ship.loc);
    undockedShip.undock(ship);
    pilot.locale = AboardShip(undockedShip);
  }

  void dock(Ship ship, SpaceEnvironment env) {
    ship.pilot.locale = AtEnvironment(env);
    remove(ship);
    final dockedShip = HangarShip.toHangar(ship);
    add(dockedShip,dockedShip.loc);
    dockedShip.systemControl = ship.systemControl;
    dockedShip.systemControl.ship = dockedShip;
    dockedShip.inventory = ship.inventory;
  }
}


