import 'dart:math';
import 'package:crawlspace_engine/galaxy/geometry/coord_3d.dart';
import 'package:crawlspace_engine/galaxy/geometry/grid.dart';
import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/plan_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/ship_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/star_reg.dart';
import '../../item.dart';
import '../geometry/location.dart';
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

typedef ItemMap = Map<SpaceLocation, Set<Item>>;
typedef ItemEntry = MapEntry<SpaceLocation, Set<Item>>;
typedef ItemSet = Set<ItemEntry>;

enum OccupancyPolicy {
  single,
  multiple,
}

abstract class SpaceRegistry<T extends Locatable<L>, L extends SpaceLocation> {
  //static const _empty = <T>{}; // won't work directly because T is generic
  final Map<T, L> _locations = {};
  final Map<System, Set<T>> _bySystem = {};
  T? _singleOrNull(Set<T> bucket, Object key) {
    if (bucket.isEmpty) return null;
    if (bucket.length > 1) {
      throw StateError(
        'Expected single $T at $key, found ${bucket.length}',
      );
    }
    return bucket.first;
  }

  void _checkBucketOccupancy(Set<T> bucket, SpaceLocation key, {required Domain domain}) {
    if (occupancyPolicies[domain] == OccupancyPolicy.single && bucket.isNotEmpty) {
      throw StateError('$T ${bucket.first} already at $key');
    }
  }

  //empty = multiple
  Map<Domain, OccupancyPolicy> get occupancyPolicies => const {};

  void register(T obj, L loc) {
    assert(
    !_locations.containsKey(obj),
    '$obj is already registered at ${_locations[obj]}',
    );
    obj.onRegistered(loc);
    _locations[obj] = loc;
    _bySystem.putIfAbsent(loc.system, () => <T>{}).add(obj);
    onRegister(obj, loc);
  }

  void move(T obj, L newLoc) {
    remove(obj, moving: true);
    register(obj, newLoc);
  }

  L remove(T obj, {bool moving = false}) {
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
  Set<T> inSystem(System s) => _bySystem[s] ?? <T>{};

  void onRegister(T obj, L loc) {}
  void onRemove(T obj, L loc) {}
}

abstract class _SectorIndexedRegistry<T extends Locatable<L>, L extends SystemLocation>
    extends SpaceRegistry<T, L> {
  final Map<SectorLocation, Set<T>> _bySector = {};
  Set<T> inSector(SectorLocation s) => _bySector[s] ?? <T>{};
  T? singleAtSector(SectorLocation loc) => _singleOrNull(inSector(loc), loc);

  @override
  void register(T obj, L loc) {
    final key = SectorLocation(loc.system, loc.sectorCoord);
    final bucket = _bySector.putIfAbsent(key, () => <T>{});
    _checkBucketOccupancy(bucket, key, domain: Domain.system);
    super.register(obj, loc);
    bucket.add(obj);
  }

  @override
  L remove(T obj, {bool moving = false}) {
    final old = super.remove(obj, moving: moving);
    final key = SectorLocation(old.system, old.sectorCoord);
    final bucket = _bySector[key];
    if (bucket == null || !bucket.remove(obj)) {
      throw StateError('Unexpected registry state for $obj at $key');
    }
    if (bucket.isEmpty) _bySector.remove(key);
    return old;
  }
}

abstract class SectorRegistry<T extends Locatable<SectorLocation>>
    extends _SectorIndexedRegistry<T, SectorLocation> {}

abstract class _ImpulseIndexedRegistry<T extends Locatable<L>, L extends ImpulseScope>
    extends _SectorIndexedRegistry<T, L> {
  final Map<ImpulseLocation, Set<T>> _byImpulse = {};
  Set<T> inImpulse(ImpulseLocation loc) => _byImpulse[loc] ?? <T>{};
  T? singleAtImpulse(ImpulseLocation loc) => _singleOrNull(inImpulse(loc), loc);

  @override
  void register(T obj, L loc) {
    final key = ImpulseLocation(loc.system, loc.sectorCoord, loc.impulseCoord);
    final bucket = _byImpulse.putIfAbsent(key, () => <T>{});
    _checkBucketOccupancy(bucket, key, domain: Domain.impulse );
    super.register(obj, loc);
    bucket.add(obj);
  }

  @override
  L remove(T obj, {bool moving = false}) {
    final old = super.remove(obj, moving: moving);
    final key = ImpulseLocation(old.system, old.sectorCoord, old.impulseCoord);
    final bucket = _byImpulse[key];
    if (bucket == null || !bucket.remove(obj)) {
      throw StateError('Unexpected registry state for $obj at $key');
    }
    if (bucket.isEmpty) _byImpulse.remove(key);
    return old;
  }
}

abstract class ImpulseRegistry<T extends Locatable<ImpulseLocation>>
    extends _ImpulseIndexedRegistry<T, ImpulseLocation> {

  Coord3D randomEmptyCoord(
      System system,
      Coord3D sectorCoord,
      GridDim dim,
      Random rnd,
      ) {
    Coord3D c;
    do {
      c = dim.rndCoord(rnd);
    } while (inImpulse(ImpulseLocation(system, sectorCoord, c)).isNotEmpty);
    return c;
  }
}

abstract class _OrbitalIndexedRegistry<T extends Locatable<L>, L extends OrbitalLocation>
    extends _ImpulseIndexedRegistry<T, L> {
  final Map<OrbitalLocation, Set<T>> _byOrbital = {};
  Set<T> inOrbital(OrbitalLocation loc) => _byOrbital[loc] ?? <T>{};
  T? singleAtOrbital(OrbitalLocation loc) => _singleOrNull(inOrbital(loc), loc);

  @override
  void register(T obj, L loc) {
    final key = OrbitalLocation(
      loc.system,
      loc.sectorCoord,
      loc.impulseCoord,
      loc.orbitalCoord,
    );
    final bucket = _byOrbital.putIfAbsent(key, () => <T>{});
    _checkBucketOccupancy(bucket, key, domain: Domain.orbital);
    super.register(obj, loc);
    bucket.add(obj);
  }

  @override
  L remove(T obj, {bool moving = false}) {
    final old = super.remove(obj, moving: moving);
    final key = OrbitalLocation(
      old.system,
      old.sectorCoord,
      old.impulseCoord,
      old.orbitalCoord,
    );
    final bucket = _byOrbital[key];
    if (bucket == null || !bucket.remove(obj)) {
      throw StateError('Unexpected registry state for $obj at $key');
    }
    if (bucket.isEmpty) _byOrbital.remove(key);
    return old;
  }
}

abstract class OrbitalRegistry<T extends Locatable<OrbitalLocation>>
    extends _OrbitalIndexedRegistry<T, OrbitalLocation> {

  Coord3D randomEmptyCoord(
      System system,
      Coord3D sectorCoord,
      Coord3D impCoord,
      GridDim dim,
      Random rnd,
      ) {
    Coord3D c;
    do {
      c = dim.rndCoord(rnd);
    } while (inOrbital(OrbitalLocation(system, sectorCoord, impCoord, c)).isNotEmpty);
    return c;
  }
}
