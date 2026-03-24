import 'package:crawlspace_engine/galaxy/models/sub_model.dart';
import 'package:crawlspace_engine/galaxy/reg/pilot_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/plan_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/ship_reg.dart';
import 'package:crawlspace_engine/galaxy/reg/star_reg.dart';
import '../../item.dart';
import '../geometry/location.dart';
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

abstract class SpaceRegistry<T> {
  final Map<T, ImpulseLocation> _locations = {};
  final Map<System, Set<T>> _bySystem = {};
  final Map<SectorLocation, Set<T>> _bySector = {};
  final Map<ImpulseLocation, T> _byImpulse = {};

  void register(T obj, ImpulseLocation loc) {
    _locations[obj] = loc;
    _bySystem.putIfAbsent(loc.system, () => {}).add(obj);
    _bySector.putIfAbsent(
      SectorLocation(loc.system, loc.sectorCoord),
          () => {},
    ).add(obj);

    assert(
    !_byImpulse.containsKey(loc),
    '$T ${_byImpulse[loc]} already at $loc',
    );
    _byImpulse[loc] = obj;
    onRegister(obj, loc);
  }

  void move(T obj, ImpulseLocation newLoc) {
    final old = _locations[obj];
    if (old != null) {
      _bySystem[old.system]?.remove(obj);
      _bySector[SectorLocation(old.system, old.sectorCoord)]?.remove(obj);
      _byImpulse.remove(old);
      onRemove(obj, old);
    }
    register(obj, newLoc);
  }

  ImpulseLocation? locationOf(T obj) => _locations[obj];
  Set<T> inSystem(System s) => _bySystem[s] ?? {};
  Set<T> inSector(SectorLocation s) => _bySector[s] ?? {};
  T? byImpulse(ImpulseLocation loc) => _byImpulse[loc];

  void onRegister(T obj, ImpulseLocation loc) {}
  void onRemove(T obj, ImpulseLocation loc) {}
}





