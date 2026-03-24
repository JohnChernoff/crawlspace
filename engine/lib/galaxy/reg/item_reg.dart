import 'package:collection/collection.dart';
import 'package:crawlspace_engine/galaxy/reg/reg.dart';
import '../../item.dart';
import '../galaxy.dart';
import '../geometry/location.dart';
import '../system.dart';

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
