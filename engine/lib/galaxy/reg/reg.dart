import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/plan_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/ship_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/star_reg.dart';
import 'package:crawlspace_engine/ship/nav.dart';
import '../../actors/pilot.dart';
import '../../item.dart';
import '../../ship/ship.dart';
import '../geometry/location.dart';
import '../geometry/object.dart';
import '../system.dart';
import 'item_reg.dart';
import 'locatables.dart';

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

abstract class SpaceRegistry<T extends Locatable<L>, L extends SpaceLocation> {
  final Map<T, L> _locations = {};
  final Map<System, Set<T>> _bySystem = {};

  void register(T obj, L loc) {
    assert(!_locations.containsKey(obj), '$obj is already registered at ${_locations[obj]}',);
    obj.onRegistered(loc);
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

    if (!moving) obj.onRemoved();
    onRemove(obj, old);
    return old;
  }

  L? locationOf(T obj) => _locations[obj];
  Set<T> inSystem(System s) => _bySystem[s] ?? {};

  void onRegister(T obj, L loc) {}
  void onRemove(T obj, L loc) {}
}

abstract class _SectorIndexedRegistry<T extends Locatable<L>, L extends SystemLocation> extends SpaceRegistry<T, L> {
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

abstract class SectorRegistry<T extends Locatable<SectorLocation>>
    extends _SectorIndexedRegistry<T, SectorLocation> {
}

abstract class _ImpulseIndexedRegistry<T extends Locatable<L>, L extends ImpulseScope>
    extends _SectorIndexedRegistry<T, L> {
  final Map<ImpulseLocation, T> _byImpulse = {};

  T? byImpulse(ImpulseLocation loc) => _byImpulse[loc];

  @override
  void register(T obj, L loc) {
    final key = ImpulseLocation(loc.system, loc.sectorCoord, loc.impulseCoord);
    assert(!_byImpulse.containsKey(key), '$T ${_byImpulse[key]} already at $key');
    super.register(obj, loc);
    _byImpulse[key] = obj;
  }

  @override
  L remove(T obj, {moving = false}) {
    final old = super.remove(obj, moving: moving);
    final key = ImpulseLocation(old.system, old.sectorCoord, old.impulseCoord);
    if (!identical(_byImpulse[key], obj)) {
      throw StateError('Unexpected registry state for $obj at $key');
    }
    _byImpulse.remove(key);
    return old;
  }
}

abstract class ImpulseRegistry<T extends Locatable<ImpulseLocation>>
    extends _ImpulseIndexedRegistry<T, ImpulseLocation> {

  Coord3D randomEmptyCoord(System system, Coord3D sectorCoord, GridDim dim, Random rnd) {
    var c;
    do {
      c = dim.rndCoord(rnd);
    }
    while (byImpulse(ImpulseLocation(system, sectorCoord, c)) != null);
    return c;
  }
}

abstract class _OrbitalIndexedRegistry<T extends Locatable<L>, L extends OrbitalLocation>
    extends _ImpulseIndexedRegistry<T, L> {
  final Map<OrbitalLocation, T> _byOrbital = {};

  T? byOrbital(OrbitalLocation loc) => _byOrbital[loc];

  @override
  void register(T obj, L loc) {
    final key = OrbitalLocation(loc.system, loc.sectorCoord, loc.impulseCoord, loc.orbitalCoord);
    assert(!_byOrbital.containsKey(key), '$T ${_byOrbital[key]} already at $key');
    super.register(obj, loc);
    _byOrbital[key] = obj;
  }

  @override
  L remove(T obj, {moving = false}) {
    final old = super.remove(obj, moving: moving);
    final key = OrbitalLocation(old.system, old.sectorCoord, old.impulseCoord, old.orbitalCoord);
    if (!identical(_byOrbital[key], obj)) {
      throw StateError('Unexpected registry state for $obj at $key');
    }
    _byOrbital.remove(key);
    return old;
  }
}

abstract class OrbitalRegistry<T extends Locatable<OrbitalLocation>>
    extends _OrbitalIndexedRegistry<T, OrbitalLocation> {
  Coord3D randomEmptyCoord(System system, Coord3D sectorCoord, Coord3D impCoord, GridDim dim, Random rnd) {
    var c;
    do {
      c = dim.rndCoord(rnd);
    }
    while (byOrbital(OrbitalLocation(system, sectorCoord, impCoord, c)) != null);
    return c;
  }
}



/*
abstract class ImpulseRegistryz<T extends Locatable<ImpulseLocation>>
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
 */